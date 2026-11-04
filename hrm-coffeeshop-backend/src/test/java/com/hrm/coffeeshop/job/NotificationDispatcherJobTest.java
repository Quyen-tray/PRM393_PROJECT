package com.hrm.coffeeshop.job;

import com.hrm.coffeeshop.domain.Notification;
import com.hrm.coffeeshop.repository.NotificationRepository;
import com.hrm.coffeeshop.shared.service.PushGateway;
import org.junit.jupiter.api.Test;
import org.springframework.transaction.TransactionStatus;
import org.springframework.transaction.support.TransactionCallback;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;
import java.util.function.Consumer;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class NotificationDispatcherJobTest {
    private final NotificationRepository repo = mock(NotificationRepository.class);
    private final PushGateway push = mock(PushGateway.class);
    private final TransactionTemplate tx = mock(TransactionTemplate.class);
    private final Clock clock = Clock.fixed(Instant.parse("2036-01-01T00:00:00Z"), ZoneOffset.UTC);

    private NotificationDispatcherJob job() {
        when(tx.execute(any())).thenAnswer(invocation -> {
            TransactionCallback<?> callback = invocation.getArgument(0);
            return callback.doInTransaction(mock(TransactionStatus.class));
        });
        doAnswer(invocation -> {
            Consumer<TransactionStatus> callback = invocation.getArgument(0);
            callback.accept(mock(TransactionStatus.class));
            return null;
        }).when(tx).executeWithoutResult(any());
        return new NotificationDispatcherJob(repo, push, tx, clock);
    }

    @Test
    void successfulDeliveryIsMarkedSentAfterClaim() throws Exception {
        Notification n = notification((short) 0);
        when(repo.findTop100ByDeliveryStatusOrderByCreatedAtAsc("PENDING")).thenReturn(List.of(n));
        when(repo.claimForDispatch(7L, (short) 0)).thenAnswer(inv -> {
            n.setAttemptCount((short) 1);
            return 1;
        });
        when(repo.findById(7L)).thenReturn(Optional.of(n));
        when(push.send(n)).thenReturn(true);

        job().dispatch();

        assertEquals("SENT", n.getDeliveryStatus());
        assertEquals(clock.instant(), n.getSentAt());
        verify(tx).execute(any());
        verify(tx).executeWithoutResult(any());
    }

    @Test
    void failedDeliveryIsRetriedAndMarkedFailedAtFifthAttempt() throws Exception {
        Notification n = notification((short) 4);
        when(repo.findTop100ByDeliveryStatusOrderByCreatedAtAsc("PENDING")).thenReturn(List.of(n));
        when(repo.claimForDispatch(7L, (short) 4)).thenAnswer(inv -> {
            n.setAttemptCount((short) 5);
            return 1;
        });
        when(repo.findById(7L)).thenReturn(Optional.of(n));
        when(push.send(n)).thenReturn(false);

        job().dispatch();

        assertEquals("FAILED", n.getDeliveryStatus());
        assertNull(n.getSentAt());
    }

    @Test
    void pushExceptionLeavesNotificationPendingForRetry() {
        Notification n = notification((short) 1);
        when(repo.findTop100ByDeliveryStatusOrderByCreatedAtAsc("PENDING")).thenReturn(List.of(n));
        when(repo.claimForDispatch(7L, (short) 1)).thenAnswer(inv -> {
            n.setAttemptCount((short) 2);
            return 1;
        });
        when(repo.findById(7L)).thenReturn(Optional.of(n));
        when(push.send(n)).thenThrow(new IllegalStateException("gateway unavailable"));

        job().dispatch();

        assertEquals("PENDING", n.getDeliveryStatus());
        assertEquals((short) 2, n.getAttemptCount());
        assertNull(n.getSentAt());
    }

    @Test
    void losingAtomicClaimSkipsPush() throws Exception {
        Notification n = notification((short) 2);
        when(repo.findTop100ByDeliveryStatusOrderByCreatedAtAsc("PENDING")).thenReturn(List.of(n));
        when(repo.claimForDispatch(7L, (short) 2)).thenReturn(0);

        job().dispatch();

        verifyNoInteractions(push);
        verify(repo, never()).findById(7L);
    }

    private static Notification notification(short attempts) {
        Notification n = new Notification();
        n.setNotificationId(7L);
        n.setAttemptCount(attempts);
        n.setDeliveryStatus("PENDING");
        return n;
    }
}
