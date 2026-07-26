/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.facebook.thrift.transport.unified;

import io.netty.handler.ssl.util.SelfSignedCertificate;
import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.cert.CertificateException;
import java.util.ArrayList;
import java.util.List;

/**
 * Utility class for locating or generating certificates for testing.
 *
 * <p>FBThrift's C++ tests use Folly's canonical test certificate fixture. Java tests reuse that
 * fixture when Folly is available through the source tree or CMake install prefix, and fall back to
 * a Netty-generated certificate for standalone FBThrift builds.
 */
public final class TestCertificateUtil {
  private static final String CERTIFICATE_FILE = "tests-cert.pem";
  private static final String PRIVATE_KEY_FILE = "tests-key.pem";
  private static final String CA_FILE = "ca-cert.pem";
  private static final String FOLLY_CERTIFICATE_RELATIVE_PATH =
      "folly/io/async/test/certs";
  private static final String FOLLY_INSTALLED_CERTIFICATE_RELATIVE_PATH =
      "share/" + FOLLY_CERTIFICATE_RELATIVE_PATH;

  private static SelfSignedCertificate generatedCertificate;
  private static Path certificateFile;
  private static Path privateKeyFile;
  private static Path caFile;

  private TestCertificateUtil() {}

  /**
   * Initializes the shared certificate fixture.
   *
   * @throws CertificateException if certificate generation fails
   * @throws IOException if file writing fails
   */
  public static synchronized void initialize() throws CertificateException, IOException {
    if (certificateFile != null) {
      return;
    }

    Path follyCertificateDirectory = findFollyCertificateDirectory();
    if (follyCertificateDirectory != null) {
      privateKeyFile = follyCertificateDirectory.resolve(PRIVATE_KEY_FILE);
      certificateFile = follyCertificateDirectory.resolve(CERTIFICATE_FILE);
      caFile = follyCertificateDirectory.resolve(CA_FILE);
      return;
    }

    generatedCertificate = new SelfSignedCertificate();
    privateKeyFile = generatedCertificate.privateKey().toPath();
    certificateFile = generatedCertificate.certificate().toPath();
    caFile = certificateFile;
  }

  /**
   * Gets the path to the private key file.
   *
   * @return path to key file
   */
  public static String getKeyFilePath() {
    return requireInitialized(privateKeyFile).toString();
  }

  /**
   * Gets the path to the certificate file.
   *
   * @return path to cert file
   */
  public static String getCertFilePath() {
    return requireInitialized(certificateFile).toString();
  }

  /**
   * Gets the path to the CA file.
   *
   * @return path to CA file
   */
  public static String getCAFilePath() {
    return requireInitialized(caFile).toString();
  }

  /** Cleans up certificate resources. */
  public static synchronized void cleanup() {
    if (generatedCertificate != null) {
      generatedCertificate.delete();
      generatedCertificate = null;
    }
    privateKeyFile = null;
    certificateFile = null;
    caFile = null;
  }

  private static Path requireInitialized(Path path) {
    if (path == null) {
      throw new IllegalStateException("TestCertificateUtil.initialize() has not been called");
    }
    return path;
  }

  private static Path findFollyCertificateDirectory() {
    List<Path> candidates = new ArrayList<>();

    addPath(candidates, System.getProperty("fbthrift.folly.test.certs"));
    addPath(candidates, System.getenv("FOLLY_TEST_CERTS"));

    String follyRoot = System.getenv("FOLLY_ROOT");
    if (follyRoot != null && !follyRoot.isBlank()) {
      Path root = Path.of(follyRoot);
      candidates.add(root.resolve(FOLLY_CERTIFICATE_RELATIVE_PATH));
      candidates.add(root.resolve(FOLLY_INSTALLED_CERTIFICATE_RELATIVE_PATH));
    }

    String cmakePrefixPath = System.getenv("CMAKE_PREFIX_PATH");
    if (cmakePrefixPath != null && !cmakePrefixPath.isBlank()) {
      String normalizedPrefixPath =
          File.pathSeparatorChar == ':' ? cmakePrefixPath.replace(';', ':') : cmakePrefixPath;
      for (String prefix :
          normalizedPrefixPath.split(java.util.regex.Pattern.quote(File.pathSeparator))) {
        if (!prefix.isBlank()) {
          candidates.add(
              Path.of(prefix).resolve(FOLLY_INSTALLED_CERTIFICATE_RELATIVE_PATH));
        }
      }
    }

    String fbthriftSourceRoot = System.getProperty("fbthrift.source.root");
    if (fbthriftSourceRoot != null && !fbthriftSourceRoot.isBlank()) {
      Path sourceRoot = Path.of(fbthriftSourceRoot).toAbsolutePath().normalize();
      Path parent = sourceRoot.getParent();
      if (parent != null) {
        candidates.add(
            parent.resolve("folly").resolve(FOLLY_CERTIFICATE_RELATIVE_PATH));
      }
    }

    for (Path candidate : candidates) {
      Path normalized = candidate.toAbsolutePath().normalize();
      if (isCertificateDirectory(normalized)) {
        return normalized;
      }
    }
    return null;
  }

  private static void addPath(List<Path> candidates, String value) {
    if (value != null && !value.isBlank()) {
      candidates.add(Path.of(value));
    }
  }

  private static boolean isCertificateDirectory(Path directory) {
    return Files.isRegularFile(directory.resolve(PRIVATE_KEY_FILE))
        && Files.isReadable(directory.resolve(PRIVATE_KEY_FILE))
        && Files.isRegularFile(directory.resolve(CERTIFICATE_FILE))
        && Files.isReadable(directory.resolve(CERTIFICATE_FILE))
        && Files.isRegularFile(directory.resolve(CA_FILE))
        && Files.isReadable(directory.resolve(CA_FILE));
  }
}
