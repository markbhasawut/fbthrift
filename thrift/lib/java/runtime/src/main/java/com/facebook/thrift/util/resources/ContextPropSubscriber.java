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

/** Subscriber that will forward ContextData for keys provided in ContextPropagationRegistry */
package com.facebook.thrift.util.resources;

import com.facebook.nifty.core.RequestContext;
import com.facebook.nifty.core.RequestContexts;
import java.util.HashMap;
import java.util.Map;
import java.util.Set;
import org.reactivestreams.Subscription;
import reactor.core.CoreSubscriber;
import reactor.util.context.Context;

public class ContextPropSubscriber<T> implements CoreSubscriber<T> {
  private final CoreSubscriber<T> delegate;
  private final Set<String> contextDataKeys;
  private final Map<String, Object> contextData = new HashMap<>();

  public ContextPropSubscriber(CoreSubscriber<T> delegate) {
    this.delegate = delegate;
    this.contextDataKeys = Set.copyOf(ContextPropagationRegistry.getContextPropagationKeys());
  }

  @Override
  public void onSubscribe(Subscription s) {
    // Capture before invoking the delegate: onSubscribe is allowed to request synchronously, which
    // may produce signals before delegate.onSubscribe returns.
    RequestContext context = RequestContexts.getCurrentContext();
    if (context != null) {
      for (String key : contextDataKeys) {
        Object value = context.getContextData(key);
        if (value != null) {
          contextData.put(key, value);
        }
      }
    }
    delegate.onSubscribe(s);
  }

  @Override
  public void onNext(T t) {
    withContextData(() -> delegate.onNext(t));
  }

  @Override
  public void onError(Throwable t) {
    withContextData(() -> delegate.onError(t));
  }

  @Override
  public void onComplete() {
    withContextData(delegate::onComplete);
  }

  @Override
  public Context currentContext() {
    // Reactor context flows from the downstream subscriber towards upstream operators. Returning
    // Context.empty() here makes every upstream contextWrite invisible once the global hook is
    // enabled.
    return delegate.currentContext();
  }

  private void withContextData(Runnable signal) {
    if (contextDataKeys.isEmpty()) {
      signal.run();
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
      signal.run();
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
