/**
 * chain_engine.ts — Chain Integrity Engine
 *
 * Every transaction is cryptographically linked to the previous one via SHA-256.
 * This creates a tamper-evident ledger: if any record is altered, the chain breaks.
 *
 * Based on the Velvet tokenomics engine (Python prototype).
 * Adapted for Prisma + PostgreSQL.
 */

import { createHash } from 'crypto';
import { PrismaClient, Prisma, TxType } from '@prisma/client';

// Genesis hash — the anchor point of the chain (64 zeros)
const GENESIS_HASH = '0'.repeat(64);

// ─── Hash Computation ────────────────────────────────────────────────────────

/**
 * Deterministic TX hash. All fields are included so any tampering
 * changes the hash and breaks the chain link.
 */
export function computeTxHash(params: {
    blockNumber: number;
    prevHash: string;
    userId: string;
    tokenType: string;
    amount: string;
    txType: string;
    campaignId: string | null;
    timestamp: number;
}): string {
    const data = JSON.stringify({
        block: params.blockNumber,
        prev: params.prevHash,
        user: params.userId,
        token: params.tokenType,
        amount: params.amount,
        type: params.txType,
        campaign: params.campaignId,
        ts: params.timestamp,
    }, Object.keys({
        block: 0, prev: '', user: '', token: '', amount: '', type: '', campaign: '', ts: 0,
    }).sort());

    return createHash('sha256').update(data, 'utf8').digest('hex');
}

// ─── Chain Helpers ───────────────────────────────────────────────────────────

/**
 * Get the hash of the last transaction in the chain.
 * Returns GENESIS_HASH if the ledger is empty.
 */
export async function getLastHash(
    tx: Prisma.TransactionClient | PrismaClient
): Promise<string> {
    const last = await (tx as any).transaction.findFirst({
        where: { blockNumber: { not: null } },
        orderBy: { blockNumber: 'desc' },
        select: { txHash: true },
    });
    return last?.txHash ?? GENESIS_HASH;
}

/**
 * Get the next block number.
 */
export async function getNextBlock(
    tx: Prisma.TransactionClient | PrismaClient
): Promise<number> {
    const last = await (tx as any).transaction.findFirst({
        where: { blockNumber: { not: null } },
        orderBy: { blockNumber: 'desc' },
        select: { blockNumber: true },
    });
    return (last?.blockNumber ?? 0) + 1;
}

// ─── Record Chained Transaction ──────────────────────────────────────────────

export interface ChainedTxParams {
    userId: string;
    amount: Prisma.Decimal | string | number;
    type: TxType;
    note?: string;
    campaignId?: string | null;
    ipHash?: string | null;
    walletId?: string | null;
    toWalletId?: string | null;
    epochDay?: number | null;
}

/**
 * Records a transaction with chain integrity.
 * Must be called inside a Prisma interactive transaction.
 */
export async function recordChainedTransaction(
    tx: Prisma.TransactionClient,
    params: ChainedTxParams
): Promise<string> {
    const timestamp = Date.now();
    const blockNumber = await getNextBlock(tx);
    const prevHash = await getLastHash(tx);
    const amountStr = typeof params.amount === 'object'
        ? (params.amount as Prisma.Decimal).toFixed(6)
        : String(params.amount);

    const txHash = computeTxHash({
        blockNumber,
        prevHash,
        userId: params.userId,
        tokenType: params.type.startsWith('RAC') ? 'RAC' : 'WAC',
        amount: amountStr,
        txType: params.type,
        campaignId: params.campaignId ?? null,
        timestamp,
    });

    await (tx as any).transaction.create({
        data: {
            userId: params.userId,
            amount: new Prisma.Decimal(amountStr),
            type: params.type,
            note: params.note ?? null,
            blockNumber,
            txHash,
            prevTxHash: prevHash,
            campaignId: params.campaignId ?? null,
            ipHash: params.ipHash ?? null,
            walletId: params.walletId ?? null,
            toWalletId: params.toWalletId ?? null,
            epochDay: params.epochDay ?? null,
        },
    });

    return txHash;
}

// ─── Chain Verification ──────────────────────────────────────────────────────

export interface ChainError {
    blockNumber: number;
    error: 'BROKEN_CHAIN' | 'TAMPERED_DATA';
    detail: string;
}

export interface ChainVerificationResult {
    valid: boolean;
    blocksScanned: number;
    errors: ChainError[];
}

/**
 * Verifies the entire transaction chain from genesis to tip.
 * Re-computes every hash and checks prev_tx_hash linkage.
 */
export async function verifyChain(
    prisma: PrismaClient
): Promise<ChainVerificationResult> {
    const rows = await prisma.transaction.findMany({
        where: { blockNumber: { not: null } },
        orderBy: { blockNumber: 'asc' },
        select: {
            blockNumber: true,
            txHash: true,
            prevTxHash: true,
            userId: true,
            amount: true,
            type: true,
            campaignId: true,
            createdAt: true,
        },
    });

    if (rows.length === 0) {
        return { valid: true, blocksScanned: 0, errors: [] };
    }

    const errors: ChainError[] = [];
    let expectedPrev = GENESIS_HASH;

    for (const row of rows) {
        const bn = row.blockNumber!;

        // 1. Check prev_hash linkage
        if (row.prevTxHash !== expectedPrev) {
            errors.push({
                blockNumber: bn,
                error: 'BROKEN_CHAIN',
                detail: `Block #${bn} prev hash mismatch. Expected: ${expectedPrev.slice(0, 16)}..., Found: ${(row.prevTxHash ?? '').slice(0, 16)}...`,
            });
        }

        // 2. Re-compute hash and verify
        const recalculated = computeTxHash({
            blockNumber: bn,
            prevHash: row.prevTxHash ?? GENESIS_HASH,
            userId: row.userId,
            tokenType: row.type.startsWith('RAC') ? 'RAC' : 'WAC',
            amount: (row.amount as Prisma.Decimal).toFixed(6),
            txType: row.type,
            campaignId: row.campaignId,
            timestamp: row.createdAt.getTime(),
        });

        if (recalculated !== row.txHash) {
            errors.push({
                blockNumber: bn,
                error: 'TAMPERED_DATA',
                detail: `Block #${bn} data has been tampered with. Hash mismatch.`,
            });
        }

        expectedPrev = row.txHash!;
    }

    return {
        valid: errors.length === 0,
        blocksScanned: rows.length,
        errors,
    };
}
