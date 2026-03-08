/**
 * ranking_engine.ts  (Updated for WAC + RAC unified ranking)
 *
 * Builds a single ranked list mixing:
 *   - WAC users  → ranked by wacBalance, positive contribution to icon area
 *   - RAC pools  → ranked by totalBalance, negative contribution to icon area
 *
 * Both types share the same sort key (balance DESC, timestamp ASC tie-break).
 * RAC pool participants are counted as individual "usersBelow" entries.
 */

export interface UserWacRow {
    userId: string;
    wacBalance: number;       // parsed from Prisma Decimal
    balanceUpdatedAt: Date;
}

export interface RacPoolRow {
    poolId: string;
    targetUserId: string;
    totalBalance: number;     // parsed from Prisma BigInt
    participantCount: number;
    createdAt: Date;          // tie-breaker for RAC pools
}

// ─── Unified entry types ───────────────────────────────────────────────────────

export type UnifiedRankedEntry =
    | WacRankedEntry
    | RacPoolRankedEntry
    | RacParticipantSlot;

export interface WacRankedEntry {
    type: 'WAC';
    userId: string;
    balance: number;
    rank: number;
    usersBelow: number;  // all individual entities below
}

export interface RacPoolRankedEntry {
    type: 'RAC_POOL';
    poolId: string;
    targetUserId: string;
    balance: number;
    participantCount: number;
    rank: number;
    usersBelow: number;
}

/** Phantom slots — 1 per participant after the pool representative */
export interface RacParticipantSlot {
    type: 'RAC_PARTICIPANT';
    poolId: string;
    rank: number;
    usersBelow: number;
}

// ─── Sort key helpers ─────────────────────────────────────────────────────────

interface SortableEntry {
    balance: number;
    tieBreakMs: number;  // lower = earlier = wins tie
    kind: 'WAC' | 'RAC_POOL';
    raw: UserWacRow | RacPoolRow;
}

// ─── Main builder ─────────────────────────────────────────────────────────────

/**
 * Merges WAC users + RAC pools into a single ranked list.
 * RAC pool participants occupy (participantCount − 1) additional phantom slots
 * immediately below the pool representative.
 *
 * usersBelow counts all individual entities (WAC users + pool participants)
 * ranked below each entry — this is what the tier table reads.
 */
export function buildUnifiedRankedList(
    wacUsers: UserWacRow[],
    racPools: RacPoolRow[]
): UnifiedRankedEntry[] {
    // Total individual entity count: each WAC user + each RAC participant
    const totalWacUsers = wacUsers.length;
    const totalRacParticipants = racPools.reduce((s, p) => s + p.participantCount, 0);
    const totalEntities = totalWacUsers + totalRacParticipants;

    // Build sortable list of primary entries (WAC users + RAC pool representatives)
    const sortable: SortableEntry[] = [
        ...wacUsers.map((u): SortableEntry => ({
            balance: u.wacBalance,
            tieBreakMs: u.balanceUpdatedAt.getTime(),
            kind: 'WAC',
            raw: u,
        })),
        ...racPools.map((p): SortableEntry => ({
            balance: p.totalBalance,
            tieBreakMs: p.createdAt.getTime(),
            kind: 'RAC_POOL',
            raw: p,
        })),
    ];

    sortable.sort((a, b) => {
        if (b.balance !== a.balance) return b.balance - a.balance;
        return a.tieBreakMs - b.tieBreakMs; // earlier = higher rank
    });

    const result: UnifiedRankedEntry[] = [];
    // entityRank tracks how many individual entities have been placed above current
    let entityRankCursor = 0;

    for (const entry of sortable) {
        if (entry.kind === 'WAC') {
            const u = entry.raw as UserWacRow;
            entityRankCursor++;
            const rank = entityRankCursor;
            const usersBelow = totalEntities - entityRankCursor;

            result.push({
                type: 'WAC',
                userId: u.userId,
                balance: u.wacBalance,
                rank,
                usersBelow,
            });
        } else {
            const p = entry.raw as RacPoolRow;
            // Pool representative = 1 entity
            entityRankCursor++;
            const poolRank = entityRankCursor;

            // (participantCount - 1) phantom participant slots follow immediately
            // Each counts as an individual entity for usersBelow purposes
            const phantomStart = entityRankCursor + 1;
            entityRankCursor += p.participantCount - 1;
            const poolUsersBelow = totalEntities - entityRankCursor;

            result.push({
                type: 'RAC_POOL',
                poolId: p.poolId,
                targetUserId: p.targetUserId,
                balance: p.totalBalance,
                participantCount: p.participantCount,
                rank: poolRank,
                usersBelow: poolUsersBelow,
            });

            // Add phantom participant slots
            for (let i = 0; i < p.participantCount - 1; i++) {
                const slotRank = phantomStart + i;
                result.push({
                    type: 'RAC_PARTICIPANT',
                    poolId: p.poolId,
                    rank: slotRank,
                    usersBelow: totalEntities - slotRank,
                });
            }
        }
    }

    return result;
}

// ─── Icon area helpers ────────────────────────────────────────────────────────

/**
 * Returns the "effective WAC" for the icon area formula.
 * Top-100 individual entity slots are considered:
 *   - WAC user in that slot: +wacBalance
 *   - RAC pool representative: −totalBalance (negative contribution)
 *   - RAC participant slot: no contribution (phantom)
 *
 * @param unified - full unified ranked list
 * @param n       - how many top slots to consider (default 100)
 */
export function computeEffectiveTopNWac(unified: UnifiedRankedEntry[], n = 100): number {
    let effective = 0;
    let counted = 0;

    for (const entry of unified) {
        if (counted >= n) break;
        if (entry.type === 'WAC') {
            effective += entry.balance;
            counted++;
        } else if (entry.type === 'RAC_POOL') {
            effective -= entry.balance; // negative contribution
            counted++;
        } else {
            // RAC_PARTICIPANT phantom slot — counts toward top-100 slots but no area
            counted++;
        }
    }

    return Math.max(0, effective); // area can't be negative
}

// ─── Legacy helpers (backward compat) ────────────────────────────────────────

/** WAC-only ranked list (used when RAC pools don't exist yet) */
export function buildRankedList(
    users: UserWacRow[]
): Array<{ userId: string; wacBalance: number; balanceUpdatedAt: Date; rank: number; usersBelow: number }> {
    const sorted = [...users].sort((a, b) => {
        if (b.wacBalance !== a.wacBalance) return b.wacBalance - a.wacBalance;
        return a.balanceUpdatedAt.getTime() - b.balanceUpdatedAt.getTime();
    });
    return sorted.map((u, i) => ({ ...u, rank: i + 1, usersBelow: sorted.length - i - 1 }));
}

export function computeTopNTotalWac(
    ranked: Array<{ wacBalance: number }>,
    n = 100
): number {
    return ranked.slice(0, n).reduce((s, u) => s + u.wacBalance, 0);
}

export function getRankForUser(
    ranked: Array<{ userId: string; rank: number; usersBelow: number }>,
    userId: string
) {
    return ranked.find((r) => r.userId === userId) ?? null;
}
