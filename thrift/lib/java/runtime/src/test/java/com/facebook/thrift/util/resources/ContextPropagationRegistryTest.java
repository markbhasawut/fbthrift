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

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.facebook.nifty.core.RequestContext;
import com.facebook.nifty.core.RequestContexts;
import com.facebook.thrift.util.NettyNiftyRequestContext;
import java.util.HashMap;
import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import reactor.core.publisher.Mono;
import reactor.util.context.Context;

public class ContextPropagationRegistryTest {
  private static final String PROPAGATION_KEY = "context-propagation-registry-test";

  @AfterEach
  public void clearThreadLocalContext() {
    RequestContexts.clearCurrentContext();
  }

  @Test
  public void testRegistry() {
    ContextPropagationRegistry.registerContextPropagationKey(PROPAGATION_KEY);

    assertTrue(ContextPropagationRegistry.isContextPropEnabled());
    assertTrue(ContextPropagationRegistry.getContextPropagationKeys().contains(PROPAGATION_KEY));
    Assertions.assertThrows(
        UnsupportedOperationException.class,
        () -> ContextPropagationRegistry.getContextPropagationKeys().add("mutable"));
  }

  @Test
  public void hookPreservesReactorContext() {
    ContextPropagationRegistry.registerContextPropagationKey(PROPAGATION_KEY);

    String value =
        Mono.deferContextual(contextView -> Mono.just(contextView.<String>get("reactor-key")))
            .contextWrite(Context.of("reactor-key", "reactor-value"))
            .block();

    assertEquals("reactor-value", value);
  }

  @Test
  public void runnableRestoresPreviousThreadLocalValue() {
    ContextPropagationRegistry.registerContextPropagationKey(PROPAGATION_KEY);

    RequestContext source = new NettyNiftyRequestContext(new HashMap<>(), null);
    source.setContextData(PROPAGATION_KEY, "source");
    RequestContexts.setCurrentContext(source);
    ContextPropRunnable runnable =
        new ContextPropRunnable(
            () ->
                assertEquals(
                    "source",
                    RequestContexts.getCurrentContext().getContextData(PROPAGATION_KEY)));

    RequestContext target = new NettyNiftyRequestContext(new HashMap<>(), null);
    target.setContextData(PROPAGATION_KEY, "target");
    RequestContexts.setCurrentContext(target);
    runnable.run();

    assertEquals(target, RequestContexts.getCurrentContext());
    assertEquals("target", target.getContextData(PROPAGATION_KEY));
  }
}
