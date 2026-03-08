import { describe, it, expect } from 'vitest';
import {
    buildRankedList,
    computeTopNTotalWac,
    getRankForUser,
    buildUnifiedRankedList,
    computeEffectiveTopNWac,
    UserWacRow,
    RacPoolRow,
} from '../../src/engine/ranking_engine.js';

// ─── Legacy WAC-only tests ────────────────────────────────────────────────────

describe('buildRankedList', () => {
    const now = new Date('2026-01-01T00:00:00Z');
    const earlier = new Date('2025-12-01T00:00:00Z');
    const earliest = new Date('2025-11-01T00:00:00Z');

    it('sorts users by wacBalance descending', () => {
        const users = [
            { userId: 'A', wacBalance: 100, balanceUpdatedAt: now },
            { userId: 'B', wacBalance: 500, balanceUpdatedAt: now },
            { userId: 'C', wacBalance: 250, balanceUpdatedAt: now },
        ];
        const ranked = buildRankedList(users);
        expect(ranked[0]!.userId).toBe('B');
        expect(ranked[1]!.userId).toBe('C');
        expect(ranked[2]!.userId).toBe('A');
    });

    it('breaks ties by balanceUpdatedAt ascending (earlier = higher rank)', () => {
        const users = [
            { userId: 'X', wacBalance: 1000, balanceUpdatedAt: now },
            { userId: 'Y', wacBalance: 1000, balanceUpdatedAt: earlier },
            { userId: 'Z', wacBalance: 1000, balanceUpdatedAt: earliest },
        ];
        const ranked = buildRankedList(users);
        expect(ranked[0]!.userId).toBe('Z');
        expect(ranked[1]!.userId).toBe('Y');
        expect(ranked[2]!.userId).toBe('X');
    });

    it('annotates usersBelow correctly', () => {
        const users = [
            { userId: 'A', wacBalance: 300, balanceUpdatedAt: now },
            { userId: 'B', wacBalance: 200, balanceUpdatedAt: now },
            { userId: 'C', wacBalance: 100, balanceUpdatedAt: now },
        ];
        const ranked = buildRankedList(users);
        expect(ranked[0]!.usersBelow).toBe(2);
        expect(ranked[1]!.usersBelow).toBe(1);
        expect(ranked[2]!.usersBelow).toBe(0);
    });

    it('handles a single user', () => {
        const users = [{ userId: 'solo', wacBalance: 42, balanceUpdatedAt: now }];
        const ranked = buildRankedList(users);
        expect(ranked.length).toBe(1);
        expect(ranked[0]!.rank).toBe(1);
        expect(ranked[0]!.usersBelow).toBe(0);
    });

    it('handles empty list', () => {
        expect(buildRankedList([])).toEqual([]);
    });
});

describe('computeTopNTotalWac', () => {
    it('sums balances of top N users', () => {
        const ranked = Array.from({ length: 150 }, (_, i) => ({
            userId: `u${i}`,
            wacBalance: 1000 - i,
            balanceUpdatedAt: new Date(),
            rank: i + 1,
            usersBelow: 149 - i,
        }));
        expect(computeTopNTotalWac(ranked, 100)).toBe(95050);
    });
});

describe('getRankForUser', () => {
    it('returns the correct rank entry', () => {
        const now = new Date();
        const ranked = buildRankedList([
            { userId: 'alice', wacBalance: 500, balanceUpdatedAt: now },
            { userId: 'bob', wacBalance: 200, balanceUpdatedAt: now },
        ]);
        expect(getRankForUser(ranked, 'bob')!.rank).toBe(2);
    });

    it('returns null for unknown userId', () => {
        expect(getRankForUser([], 'ghost')).toBeNull();
    });
});

// ─── Unified WAC+RAC ranking tests ───────────────────────────────────────────

describe('buildUnifiedRankedList', () => {
    const now = new Date('2026-01-01T00:00:00Z');
    const earlier = new Date('2025-01-01T00:00:00Z');

    const wacUsers: UserWacRow[] = [
        { userId: 'alice', wacBalance: 50_000, balanceUpdatedAt: now },
        { userId: 'bob', wacBalance: 10_000, balanceUpdatedAt: now },
        { userId: 'carol', wacBalance: 1_000, balanceUpdatedAt: now },
    ];

    const racPools: RacPoolRow[] = [
        {
            poolId: 'pool1',
            targetUserId: 'alice',
            totalBalance: 25_000,    // ranks between alice and bob
            participantCount: 200,
            createdAt: earlier,
        },
    ];

    it('inserts RAC pool at the correct rank by balance', () => {
        const unified = buildUnifiedRankedList(wacUsers, racPools);
        const wacEntries = unified.filter((e) => e.type === 'WAC');
        const racPoolEntry = unified.find((e) => e.type === 'RAC_POOL');
        const aliceEntry = wacEntries.find((e) => (e as any).userId === 'alice');

        // alice(50k) > pool(25k) > bob(10k) > carol(1k)
        expect(aliceEntry!.rank).toBe(1);
        expect(racPoolEntry!.rank).toBe(2);
    });

    it('creates phantom participant slots immediately after pool representative', () => {
        const unified = buildUnifiedRankedList(wacUsers, racPools);
        const poolEntry = unified.find((e) => e.type === 'RAC_POOL')!;
        const phantoms = unified.filter(
            (e) => e.type === 'RAC_PARTICIPANT' && (e as any).poolId === 'pool1'
        );
        // 200 participants → 1 representative + 199 phantoms
        expect(phantoms.length).toBe(199);
        // All phantoms follow the representative
        expect(phantoms.every((p) => p.rank > poolEntry.rank)).toBe(true);
    });

    it('WAC user rank accounts for ALL individual entities above', () => {
        const unified = buildUnifiedRankedList(wacUsers, racPools);
        const bobEntry = unified.find(
            (e) => e.type === 'WAC' && (e as any).userId === 'bob'
        )!;
        // alice(rank1) + pool-rep(rank2) + 199 phantoms = 201 entities before bob
        expect(bobEntry.rank).toBe(202);
    });
});

// ─── Effective icon area tests ────────────────────────────────────────────────

describe('computeEffectiveTopNWac', () => {
    const now = new Date();

    it('subtracts RAC pool balance from effective WAC when in top-N', () => {
        const wacUsers: UserWacRow[] = [
            { userId: 'rich', wacBalance: 100_000, balanceUpdatedAt: now },
        ];
        const racPools: RacPoolRow[] = [
            {
                poolId: 'p1',
                targetUserId: 'rich',
                totalBalance: 30_000,
                participantCount: 300,
                createdAt: new Date('2020-01-01'),
            },
        ];
        const unified = buildUnifiedRankedList(wacUsers, racPools);
        // N=2: includes rich(WAC=100k) and pool(RAC=30k, negative)
        const effective = computeEffectiveTopNWac(unified, 2);
        expect(effective).toBe(70_000); // 100k − 30k
    });

    it('returns 0 if RAC pools dominate WAC in top-N', () => {
        const wacUsers: UserWacRow[] = [
            { userId: 'poor', wacBalance: 100, balanceUpdatedAt: now },
        ];
        const racPools: RacPoolRow[] = [
            {
                poolId: 'p1',
                targetUserId: 'poor',
                totalBalance: 50_000,
                participantCount: 10,
                createdAt: new Date('2020-01-01'),
            },
        ];
        const unified = buildUnifiedRankedList(wacUsers, racPools);
        // RAC pool(50k) ranks above WAC user(100), both in top-2
        const effective = computeEffectiveTopNWac(unified, 2);
        // 100 (WAC) − 50_000 (RAC) = negative → clamped to 0
        expect(effective).toBe(0);
    });

    it('WAC-only scenario returns sum of top WAC balances', () => {
        const wacUsers: UserWacRow[] = [
            { userId: 'u1', wacBalance: 1000, balanceUpdatedAt: now },
            { userId: 'u2', wacBalance: 2000, balanceUpdatedAt: now },
        ];
        const unified = buildUnifiedRankedList(wacUsers, []);
        expect(computeEffectiveTopNWac(unified, 100)).toBe(3000);
    });
});
