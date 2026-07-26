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

package com.facebook.thrift.util.resources;

import com.facebook.nifty.core.RequestContext;
import com.facebook.nifty.core.RequestContexts;
import java.util.HashMap;
import java.util.Map;
import java.util.Set;

/** Runnable that will forward ContextData for keys provided in ContextPropagationRegistry */
public final class ContextPropRunnable implements Runnable {
  private final Runnable runnable;
  private final Map<String, Object> contextData = new HashMap<>();
  private final Set<String> contextDataKeys;

  public ContextPropRunnable(Runnable runnable) {
    this.runnable = runnable;
    this.contextDataKeys = Set.copyOf(ContextPropagationRegistry.getContextPropagationKeys());

    if (!contextDataKeys.isEmpty()) {
      RequestContext requestContext = RequestContexts.getCurrentContext();
      if (requestContext != null) {
        for (String key : contextDataKeys) {
          Object value = requestContext.getContextData(key);
          if (value != null) {
            contextData.put(key, value);
          }
        }
      }
    }
  }

  @Override
  public void run() {
    if (contextDataKeys.isEmpty()) {
      runnable.run();
      return;
    }

    RequestContext previousThreadContext = RequestContexts.getCurrentContext();
    RequestContext activeContext = RequestContexts.getOrCreateCurrentContext();
    Map<String, Object> previousValues = new HashMap<>();
    for (String key : contextDataKeys) {
      Object previousValue = activeContext.getContextData(key);
      if (previousValue != null) {
        previousValues.put(key, previousValue);
      }
      Object propagatedValue = contextData.get(key);
      if (propagatedValue == null) {
        activeContext.clearContextData(key);
      } else {
        activeContext.setContextData(key, propagatedValue);
      }
    }

    try {
      runnable.run();
    } finally {
      for (String key : contextDataKeys) {
        Object previousValue = previousValues.get(key);
        if (previousValue == null) {
          activeContext.clearContextData(key);
        } else {
          activeContext.setContextData(key, previousValue);
        }
      }
      if (previousThreadContext == null) {
        RequestContexts.clearCurrentContext();
      } else {
        RequestContexts.setCurrentContext(previousThreadContext);
      }
    }
  }
}
