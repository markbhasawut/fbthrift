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

package org.apache.thrift.transport;

import java.util.Arrays;

/** In-memory transport used by FBThrift's modern-to-legacy Java compatibility tests. */
@Deprecated
public final class TMemoryBuffer extends TTransport {
  private byte[] buffer;
  private int readPosition;
  private int writePosition;

  public TMemoryBuffer(int initialCapacity) {
    buffer = new byte[Math.max(1, initialCapacity)];
  }

  @Override
  public boolean isOpen() {
    return true;
  }

  @Override
  public void open() {}

  @Override
  public void close() {}

  @Override
  public int read(byte[] destination, int offset, int length) {
    int bytesToRead = Math.min(length, writePosition - readPosition);
    if (bytesToRead > 0) {
      System.arraycopy(buffer, readPosition, destination, offset, bytesToRead);
      readPosition += bytesToRead;
    }
    return bytesToRead;
  }

  @Override
  public void write(byte[] source, int offset, int length) {
    ensureCapacity(writePosition + length);
    System.arraycopy(source, offset, buffer, writePosition, length);
    writePosition += length;
  }

  @Override
  public byte[] getBuffer() {
    return buffer;
  }

  @Override
  public int getBufferPosition() {
    return readPosition;
  }

  @Override
  public int getBytesRemainingInBuffer() {
    return writePosition - readPosition;
  }

  @Override
  public void consumeBuffer(int length) {
    if (length < 0 || length > getBytesRemainingInBuffer()) {
      throw new IllegalArgumentException("Cannot consume " + length + " bytes");
    }
    readPosition += length;
  }

  public int length() {
    return writePosition;
  }

  public byte[] toByteArray() {
    return Arrays.copyOf(buffer, writePosition);
  }

  private void ensureCapacity(int requiredCapacity) {
    if (requiredCapacity <= buffer.length) {
      return;
    }
    int grownCapacity = Math.max(requiredCapacity, buffer.length + (buffer.length >> 1) + 1);
    buffer = Arrays.copyOf(buffer, grownCapacity);
  }
}
