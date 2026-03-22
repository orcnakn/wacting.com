/**
 * ranking_engine.ts
 *
 * Builds a ranked list of WAC users sorted by wacBalance.
 * RAC pools temporarily disabled.
 */

export interface UserWacRow {
    userId: string;
    wacBalance: number;       // parsed from Prisma Decimal
    balanceUpdatedAt: Date;
}

// ─── Main ranking builder ─────────────────────────────────────────────────────

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
