#!/usr/bin/env python3
"""Security spec for Spectacle's Sparkle update install.

Spectacle launches Sparkle against the feed in its Info.plist. After the user
approves the update prompt, Sparkle downloads the enclosure, extracts it, checks
the DSA signature of the downloaded file, and installs the bundle it finds.

These tests build that sequence from the Sparkle sources pinned in
Cartfile.resolved. They fail while a zip, tar, tar.gz, or tar.bz2 entry can
replace the downloaded archive before the signature is read, so a signature of
some other archive authorizes a different bundle. They pass once extraction
cannot replace the download and a bundle is installed only when that bundle is
inside the bytes the signature actually verified.

Run:

    python3 -m unittest tests.test_sparkle_update_signature_binding -v

DMG updates are not covered: SUDiskImageUnarchiver copies mounted files into the
archive's directory with NSFileManager copyItemAtPath, which this host cannot
run. Binary-delta updates are a different path: SUBinaryDeltaUnarchiver returns
YES from mustValidateBeforeExtraction, so the driver verifies the download
before applying the delta.
"""

from __future__ import annotations

import gzip
import io
import os
import plistlib
import re
import shutil
import struct
import subprocess
import sys
import tarfile
import tempfile
import unittest
import zipfile
from dataclasses import dataclass
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
CHUNK = 256 * 1024
HOST_NAME = "Spectacle"
BUNDLE_FILE = "Spectacle.app"
BUNDLE_ID = "com.divisiblebyzero.Spectacle"
ENCLOSURE_VERSION = "2"
LEGITIMATE = b"LEGITIMATE-SPECTACLE"
MALICIOUS = b"MALICIOUS-SPECTACLE"
SPARKLE_REMOTE = "https://github.com/sparkle-project/Sparkle.git"


@dataclass
class Policy:
    must_validate_before_extraction: bool
    # "same_directory" extracts into the directory that already holds the
    # download. "unique_child" extracts into a new directory created inside it.
    extraction: str
    source_root: Path


@dataclass
class UpdateResult:
    accepted: bool
    installed_marker: bytes | None
    original_download: bytes
    download_bytes: bytes
    verified_bytes: bytes | None
    detail: str


def _sparkle_version() -> str:
    text = (REPO_ROOT / "Cartfile.resolved").read_text()
    match = re.search(r'github "sparkle-project/Sparkle" "([^"]+)"', text)
    if not match:
        raise AssertionError("Cartfile.resolved does not pin sparkle-project/Sparkle")
    return match.group(1)


def sparkle_source() -> Path:
    override = os.environ.get("SPARKLE_SOURCE_DIR")
    if override:
        root = Path(override)
    else:
        version = _sparkle_version()
        root = Path(tempfile.gettempdir()) / "spectacle-sparkle-src" / version
        marker = root / "Sparkle" / "SUPipedUnarchiver.m"
        if not marker.is_file():
            if root.exists():
                shutil.rmtree(root)
            root.parent.mkdir(parents=True, exist_ok=True)
            subprocess.check_call(
                [
                    "git",
                    "clone",
                    "--depth",
                    "1",
                    "--branch",
                    version,
                    SPARKLE_REMOTE,
                    str(root),
                ],
                env={**os.environ, "GIT_TERMINAL_PROMPT": "0"},
            )
    piped = root / "Sparkle" / "SUPipedUnarchiver.m"
    if not piped.is_file():
        raise AssertionError(f"Sparkle source at {root} has no SUPipedUnarchiver.m")
    return root


def _method_body(source: str, signature: str) -> str:
    start = source.find(signature)
    if start < 0:
        raise AssertionError(f"Sparkle source has no {signature!r}")
    next_method = source.find("\n- ", start + len(signature))
    next_class_method = source.find("\n+ ", start + len(signature))
    ends = [pos for pos in (next_method, next_class_method) if pos >= 0]
    end = min(ends) if ends else len(source)
    return source[start:end]


def load_policy(root: Path | None = None) -> Policy:
    root = root or sparkle_source()
    piped = (root / "Sparkle" / "SUPipedUnarchiver.m").read_text()
    driver = (root / "Sparkle" / "SUBasicUpdateDriver.m").read_text()
    pre_body = _method_body(piped, "+ (BOOL)mustValidateBeforeExtraction")
    if "return YES" in pre_body and "return NO" not in pre_body:
        prevalidate = True
    elif "return NO" in pre_body and "return YES" not in pre_body:
        prevalidate = False
    else:
        raise AssertionError("could not read mustValidateBeforeExtraction")

    extract_body = _method_body(piped, "- (void)extractArchivePipingDataToCommand:")
    same_directory = (
        "destination = [self.archivePath stringByDeletingLastPathComponent]" in extract_body
    )
    separate = "destination = self.extractionDirectory" in extract_body
    setter = _method_body(driver, "- (void)downloaderDidSetDestinationName:")
    unique_child = (
        "createUniqueDirectoryInDirectory:temporaryDirectory" in setter
        and "self.extractionDirectory" in setter
    )
    if same_directory and not separate:
        extraction = "same_directory"
    elif separate and unique_child and not same_directory:
        extraction = "unique_child"
    else:
        raise AssertionError(
            "unrecognized Sparkle extraction layout in "
            f"{root}: same_directory={same_directory} separate={separate} "
            f"unique_child={unique_child}"
        )
    return Policy(prevalidate, extraction, root)


# OpenSSL 3 keeps DSA in the legacy provider. Sparkle 1.22 hashes the archive
# with SHA-1 and verifies a DSA signature (SUSignatureVerifier.m,
# SecDigestTransformCreate(kSecDigestSHA1) and SecVerifyTransformCreate).
_OPENSSL_DSA = ("-provider", "legacy", "-provider", "default")


def _openssl(*args: str, input_bytes: bytes | None = None) -> subprocess.CompletedProcess:
    command, *rest = args
    return subprocess.run(
        ["openssl", command, *_OPENSSL_DSA, *rest],
        input=input_bytes,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )


def generate_dsa_keypair(directory: Path) -> tuple[Path, Path]:
    private_key = directory / "dsa_private.pem"
    public_key = directory / "dsa_public.pem"
    parameters = directory / "dsa_params.pem"
    generated = _openssl(
        "genpkey",
        "-algorithm",
        "DSA",
        "-genparam",
        "-pkeyopt",
        "dsa_paramgen_bits:1024",
        "-out",
        str(parameters),
    )
    if generated.returncode != 0:
        raise AssertionError(generated.stderr.decode())
    keyed = _openssl("genpkey", "-paramfile", str(parameters), "-out", str(private_key))
    if keyed.returncode != 0:
        raise AssertionError(keyed.stderr.decode())
    published = _openssl("pkey", "-in", str(private_key), "-pubout", "-out", str(public_key))
    if published.returncode != 0:
        raise AssertionError(published.stderr.decode())
    return private_key, public_key


def sign_file(path: Path, private_key: Path) -> bytes:
    signature = path.with_suffix(path.suffix + ".sig")
    signed = _openssl(
        "dgst",
        "-sha1",
        "-sign",
        str(private_key),
        "-out",
        str(signature),
        str(path),
    )
    if signed.returncode != 0:
        raise AssertionError(signed.stderr.decode())
    return signature.read_bytes()


def verify_file(path: Path, signature: bytes, public_key: Path) -> bool:
    signature_path = path.with_suffix(path.suffix + ".checksig")
    signature_path.write_bytes(signature)
    checked = _openssl(
        "dgst",
        "-sha1",
        "-verify",
        str(public_key),
        "-signature",
        str(signature_path),
        str(path),
    )
    return checked.returncode == 0


def _plist(public_key_name: str, version: str) -> bytes:
    return plistlib.dumps(
        {
            "CFBundleIdentifier": BUNDLE_ID,
            "CFBundleName": HOST_NAME,
            "CFBundleVersion": version,
            "SUPublicDSAKeyFile": public_key_name,
        }
    )


def app_entries(marker: bytes, public_key: bytes, version: str) -> list[tuple[str, bytes]]:
    prefix = f"{BUNDLE_FILE}/Contents"
    return [
        (f"{prefix}/Info.plist", _plist("dsa_public.pem", version)),
        (f"{prefix}/Resources/dsa_public.pem", public_key),
        (f"{prefix}/MacOS/marker", marker),
    ]


def store_zip(entries: list[tuple[str, bytes]]) -> bytes:
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w", compression=zipfile.ZIP_STORED) as archive:
        for name, payload in entries:
            archive.writestr(name, payload)
    return buffer.getvalue()


def store_tar(entries: list[tuple[str, bytes]]) -> bytes:
    buffer = io.BytesIO()
    with tarfile.open(fileobj=buffer, mode="w") as archive:
        for name, payload in entries:
            info = tarfile.TarInfo(name)
            info.size = len(payload)
            archive.addfile(info, io.BytesIO(payload))
    return buffer.getvalue()


def archive_bytes(kind: str, entries: list[tuple[str, bytes]]) -> bytes:
    if kind == "zip":
        return store_zip(entries)
    if kind == "tar":
        return store_tar(entries)
    if kind == "tar.gz":
        return gzip.compress(store_tar(entries))
    if kind == "tar.bz2":
        return subprocess.check_output(["bzip2", "-c"], input=store_tar(entries))
    raise AssertionError(kind)


def members_contain(data: bytes, kind: str, marker: bytes) -> bool:
    try:
        if kind == "zip":
            with zipfile.ZipFile(io.BytesIO(data)) as archive:
                return any(archive.read(name) == marker for name in archive.namelist())
        if kind == "tar.gz":
            data = gzip.decompress(data)
        elif kind == "tar.bz2":
            data = subprocess.check_output(["bzip2", "-dc"], input=data)
        if kind in {"tar", "tar.gz", "tar.bz2"}:
            with tarfile.open(fileobj=io.BytesIO(data), mode="r") as archive:
                for member in archive.getmembers():
                    extracted = archive.extractfile(member)
                    if extracted is not None and extracted.read() == marker:
                        return True
            return False
    except Exception:
        return False
    return False


def ditto_extract_zip(destination: Path) -> int:
    """Stand-in for `/usr/bin/ditto -x -k - <destination>`.

    Sparkle 1.22 pipes the downloaded zip into that command and appends the
    archive's parent directory. ditto reads a PKZip archive from stdin when the
    source is `-`, merges entries into the destination, and by default atomically
    swaps a replacement over an existing file (`--nonAtomicCopies` is not one of
    Sparkle's arguments). This host has no ditto binary, so the steps below are
    that contract: read each stored local-file entry from stdin and os.replace
    it into the destination, including an entry whose name is the download.
    """

    def read_exact(count: int) -> bytes | None:
        buffer = b""
        while len(buffer) < count:
            chunk = sys.stdin.buffer.read(count - len(buffer))
            if not chunk:
                return None
            buffer += chunk
        return buffer

    while True:
        signature = read_exact(4)
        if signature is None or signature != b"PK\x03\x04":
            return 0
        header = read_exact(26)
        if header is None:
            return 1
        _ver, flags, method, _time, _date, _crc, compressed, _uncompressed, name_len, extra_len = (
            struct.unpack("<HHHHHIIIHH", header)
        )
        name = read_exact(name_len)
        extra = read_exact(extra_len)
        payload = read_exact(compressed)
        if name is None or extra is None or payload is None or flags & 0x8 or method != 0:
            return 1
        entry = name.decode()
        parts = entry.split("/")
        if entry.startswith("/") or ".." in parts:
            return 1
        if entry.endswith("/"):
            (destination / entry).mkdir(parents=True, exist_ok=True)
            continue
        target = destination / entry
        target.parent.mkdir(parents=True, exist_ok=True)
        temporary = target.with_name(target.name + ".partial")
        temporary.write_bytes(payload)
        os.replace(temporary, target)


def pipe_archive(archive_path: Path, command: list[str]) -> bool:
    """Sparkle's SUPipedUnarchiver read loop, including the 256 KiB chunks."""

    expected = archive_path.stat().st_size
    if expected <= 0:
        return False
    process = subprocess.Popen(command, stdin=subprocess.PIPE)
    assert process.stdin is not None
    read = 0
    with archive_path.open("rb") as archive:
        while read < expected:
            chunk = archive.read(CHUNK)
            if not chunk:
                break
            read += len(chunk)
            process.stdin.write(chunk)
    process.stdin.close()
    status = process.wait()
    return status == 0 and read == expected


def extract_archive(kind: str, archive_path: Path, destination: Path) -> bool:
    destination.mkdir(parents=True, exist_ok=True)
    if kind == "zip":
        command = [sys.executable, str(Path(__file__).resolve()), "--ditto-extract", str(destination)]
    elif kind == "tar":
        command = ["tar", "-xC", str(destination)]
    elif kind == "tar.gz":
        command = ["tar", "-zxC", str(destination)]
    elif kind == "tar.bz2":
        command = ["tar", "-jxC", str(destination)]
    else:
        raise AssertionError(kind)
    return pipe_archive(archive_path, command)


def find_install_source(update_directory: Path) -> Path | None:
    """SUInstaller installSourcePathInUpdateFolder, for an app bundle."""

    for current in sorted(update_directory.rglob("*")):
        if current.name == BUNDLE_FILE:
            return current
        info = current / "Contents" / "Info.plist"
        if info.is_file():
            try:
                parsed = plistlib.loads(info.read_bytes())
            except Exception:
                continue
            if parsed.get("CFBundleIdentifier") == BUNDLE_ID:
                return current
    return None


def bundle_has_dsa_key(bundle: Path) -> bool:
    info_path = bundle / "Contents" / "Info.plist"
    if not info_path.is_file():
        return False
    info = plistlib.loads(info_path.read_bytes())
    key_name = info.get("SUPublicDSAKeyFile") or info.get("SUPublicDSAKey")
    if not key_name:
        return False
    if info.get("SUPublicDSAKey"):
        return True
    return (bundle / "Contents" / "Resources" / str(key_name)).is_file()


def run_update(
    kind: str,
    download: bytes,
    signature: bytes,
    public_key: Path,
    policy: Policy,
) -> UpdateResult:
    enclosure = f"Spectacle-{ENCLOSURE_VERSION}.{kind}"
    workspace = Path(tempfile.mkdtemp(prefix="spectacle-update-"))
    try:
        # SPUDownloaderSession saves the enclosure as
        # <temp>/<host name> <version>/<suggestedFilename>.
        download_dir = workspace / f"{HOST_NAME} {ENCLOSURE_VERSION}"
        download_dir.mkdir()
        archive_path = download_dir / enclosure
        archive_path.write_bytes(download)
        original = download

        def reject(detail: str) -> UpdateResult:
            return UpdateResult(
                False,
                None,
                original,
                archive_path.read_bytes(),
                None,
                detail,
            )

        prevalidated = False
        if policy.must_validate_before_extraction:
            if not verify_file(archive_path, signature, public_key):
                return reject("signature rejected before extraction")
            prevalidated = True

        if policy.extraction == "same_directory":
            extraction_dir = download_dir
        else:
            extraction_dir = download_dir / "unique-extraction"
            extraction_dir.mkdir()

        if not extract_archive(kind, archive_path, extraction_dir):
            return reject("extraction failed")

        # Validation searches the update directory. In 1.22 that directory is
        # the download directory; a separated extraction directory is searched
        # instead, and the download itself is not one of its entries.
        search_dir = extraction_dir
        bundle = find_install_source(search_dir)
        if bundle is None or not bundle_has_dsa_key(bundle):
            return reject("no bundle with a DSA public key")

        if prevalidated:
            # SUUpdateValidator skips a second archive read after prevalidation
            # and accepts an unsigned bundle when the earlier DSA check passed.
            verified = original
            dsa_ok = True
        else:
            dsa_ok = verify_file(archive_path, signature, public_key)
            verified = archive_path.read_bytes() if dsa_ok else None
        if not dsa_ok or verified is None:
            return reject("signature rejected after extraction")

        marker_path = bundle / "Contents" / "MacOS" / "marker"
        marker = marker_path.read_bytes() if marker_path.is_file() else None
        # Host is treated as code-signed and the extracted bundle as unsigned.
        # SUUpdateValidator.m accepts that combination when the DSA check passed.
        return UpdateResult(
            True,
            marker,
            original,
            archive_path.read_bytes(),
            verified,
            "installed",
        )
    finally:
        shutil.rmtree(workspace, ignore_errors=True)


class SparkleUpdateSignatureBindingTest(unittest.TestCase):
    policy: Policy
    keys: Path
    private_key: Path
    public_key: Path

    @classmethod
    def setUpClass(cls) -> None:
        cls.policy = load_policy()
        cls.keys = Path(tempfile.mkdtemp(prefix="spectacle-dsa-"))
        cls.private_key, cls.public_key = generate_dsa_keypair(cls.keys)

    @classmethod
    def tearDownClass(cls) -> None:
        shutil.rmtree(cls.keys, ignore_errors=True)

    def _signed_archive(self, kind: str, marker: bytes) -> tuple[bytes, bytes]:
        payload = archive_bytes(
            kind,
            app_entries(marker, self.public_key.read_bytes(), ENCLOSURE_VERSION)
            + [("padding.bin", b"p" * (CHUNK + 1024))],
        )
        path = self.keys / f"signed-{kind.replace('.', '-')}"
        path.write_bytes(payload)
        return payload, sign_file(path, self.private_key)

    def _attack_download(self, kind: str) -> tuple[bytes, bytes]:
        legitimate, signature = self._signed_archive(kind, LEGITIMATE)
        enclosure = f"Spectacle-{ENCLOSURE_VERSION}.{kind}"
        download = archive_bytes(
            kind,
            [(enclosure, legitimate)]
            + app_entries(MALICIOUS, self.public_key.read_bytes(), ENCLOSURE_VERSION),
        )
        return download, signature

    def _assert_rejects_unbound_bundle(self, kind: str) -> None:
        download, signature = self._attack_download(kind)
        result = run_update(kind, download, signature, self.public_key, self.policy)
        verified_covers_install = result.verified_bytes is not None and members_contain(
            result.verified_bytes, kind, result.installed_marker or b""
        )
        self.assertTrue(
            (not result.accepted)
            and result.download_bytes == result.original_download
            and not verified_covers_install,
            (
                f"{kind} update was authorized separately from the bytes that were "
                f"signed: accepted={result.accepted} detail={result.detail} "
                f"download_replaced={result.download_bytes != result.original_download} "
                f"installed={result.installed_marker!r} "
                f"verified_covers_install={verified_covers_install}"
            ),
        )
        self.assertFalse(
            result.installed_marker == MALICIOUS and result.accepted,
            f"{kind} installed the bundle that was not in the signed archive",
        )

    def test_feed_and_automatic_check_reach_sparkle(self) -> None:
        info = plistlib.loads((REPO_ROOT / "Spectacle/Supporting Files/Info.plist").read_bytes())
        defaults = plistlib.loads(
            (REPO_ROOT / "Spectacle/Resources/Property Lists/Defaults.plist").read_bytes()
        )
        delegate = (REPO_ROOT / "Spectacle/Sources/SpectacleAppDelegate.m").read_text()
        self.assertEqual(info["SUFeedURL"], "https://spectacleapp.com/updates/appcast.xml")
        self.assertTrue(str(info["SUFeedURL"]).startswith("https://"))
        self.assertEqual(info["SUPublicDSAKeyFile"], "dsa_public.pem")
        self.assertIs(info["SUEnableAutomaticChecks"], True)
        self.assertIs(info["SUAllowsAutomaticUpdates"], False)
        self.assertIs(defaults["AutomaticUpdateCheckEnabled"], True)
        self.assertIn(
            'setAutomaticallyChecksForUpdates:automaticallyChecksForUpdates',
            delegate,
        )
        public_key = REPO_ROOT / "Spectacle/Resources/Certificates/dsa_public.pem"
        self.assertTrue(public_key.is_file())
        self.assertIn("BEGIN PUBLIC KEY", public_key.read_text())
        version = _sparkle_version()
        self.assertRegex(version, r"^\d+\.\d+\.\d+$")

    def test_genuine_signed_zip_installs_the_signed_bundle(self) -> None:
        download, signature = self._signed_archive("zip", LEGITIMATE)
        result = run_update("zip", download, signature, self.public_key, self.policy)
        self.assertTrue(result.accepted, result.detail)
        self.assertEqual(result.installed_marker, LEGITIMATE)
        self.assertEqual(result.verified_bytes, result.original_download)
        self.assertTrue(members_contain(result.verified_bytes or b"", "zip", LEGITIMATE))

    def test_signature_that_does_not_match_the_download_is_rejected(self) -> None:
        download, signature = self._signed_archive("zip", LEGITIMATE)
        result = run_update("zip", download + b"tampered", signature, self.public_key, self.policy)
        self.assertFalse(result.accepted, result.detail)
        self.assertIsNone(result.installed_marker)

    def test_zip_same_name_entry_cannot_authorize_a_different_bundle(self) -> None:
        self._assert_rejects_unbound_bundle("zip")

    def test_tar_same_name_entry_cannot_authorize_a_different_bundle(self) -> None:
        self._assert_rejects_unbound_bundle("tar")

    def test_targz_same_name_entry_cannot_authorize_a_different_bundle(self) -> None:
        self._assert_rejects_unbound_bundle("tar.gz")

    def test_tarbz2_same_name_entry_cannot_authorize_a_different_bundle(self) -> None:
        self._assert_rejects_unbound_bundle("tar.bz2")

    def test_bundle_inside_the_signed_zip_stays_authorized(self) -> None:
        download, signature = self._signed_archive("zip", MALICIOUS)
        result = run_update("zip", download, signature, self.public_key, self.policy)
        self.assertTrue(result.accepted, result.detail)
        self.assertEqual(result.installed_marker, MALICIOUS)
        self.assertTrue(members_contain(result.verified_bytes or b"", "zip", MALICIOUS))
        self.assertEqual(result.download_bytes, result.original_download)


if __name__ == "__main__":
    if len(sys.argv) >= 3 and sys.argv[1] == "--ditto-extract":
        sys.exit(ditto_extract_zip(Path(sys.argv[2])))
    unittest.main()
