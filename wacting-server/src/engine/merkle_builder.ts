/**
 * merkle_builder.ts
 * Builds a Merkle tree from daily snapshot reward entries.
 *
 * Each leaf encodes: sha256(userId | epoch | rewardWac_as_string)
 * Blockchain-agnostic — swap sha256 → keccak256 when chain is chosen.
 *
 * The tree is built bottom-up. Odd-length layers duplicate the last element.
 * Pair hashing is sorted (canonical) so proof order doesn't matter.
 */

import { createHash } from 'crypto';

export interface MerkleLeafInput {
    userId: string;
    epoch: number;
    rewardWac: number; // 6 dp precision
}

export interface MerkleResult {
    root: string;                          // '0x' + hex-64
    leaves: string[];                      // ordered leaf hashes (hex)
    proofs: Map<string, MerkleProofEntry>; // userId → proof entry
}

export interface MerkleProofEntry {
    /** Ordered sibling hashes. Each entry is { hash, hasSibling }. */
    path: Array<{ sibling: string | null }>;
}

// ─── hashing helpers ──────────────────────────────────────────────────────────

function sha256(data: string): string {
    return createHash('sha256').update(data, 'utf8').digest('hex');
}

export function hashLeaf(input: MerkleLeafInput): string {
    const payload = `${input.userId}|${input.epoch}|${input.rewardWac.toFixed(6)}`;
    return sha256(payload);
}

/** Canonical pair hash: always sort so order doesn't matter. */
function hashPair(a: string, b: string): string {
    const [lo, hi] = a <= b ? [a, b] : [b, a];
    return sha256(lo + hi);
}

// ─── tree builder ─────────────────────────────────────────────────────────────

export function buildMerkleTree(inputs: MerkleLeafInput[]): MerkleResult {
    if (inputs.length === 0) {
        return {
            root: '0x' + '0'.repeat(64),
            leaves: [],
            proofs: new Map(),
        };
    }

    // Track userId → position in leaves array
    const userIdToIndex = new Map<string, number>();
    const leaves: string[] = inputs.map((input, idx) => {
        const h = hashLeaf(input);
        userIdToIndex.set(input.userId, idx);
        return h;
    });

    // Build all tree layers bottom-up
    // layers[0] = leaves, layers[last] = [root]
    const layers: string[][] = [leaves];
    let cur = leaves;

    while (cur.length > 1) {
        const next: string[] = [];
        for (let i = 0; i < cur.length; i += 2) {
            const left = cur[i]!;
            // Odd last node → pair with itself (duplication)
            const right = i + 1 < cur.length ? cur[i + 1]! : left;
            next.push(hashPair(left, right));
        }
        layers.push(next);
        cur = next;
    }

    const root = cur[0]!;

    // Build proof paths — store sibling OR null (no sibling = self-duplicate)
    const proofs = new Map<string, MerkleProofEntry>();

    for (const [userId, startIdx] of userIdToIndex) {
        const path: Array<{ sibling: string | null }> = [];
        let idx = startIdx;

        for (let li = 0; li < layers.length - 1; li++) {
            const layer = layers[li]!;
            const isRight = idx % 2 === 1;
            const siblingIdx = isRight ? idx - 1 : idx + 1;

            if (siblingIdx < layer.length) {
                path.push({ sibling: layer[siblingIdx]! });
            } else {
                // Node is last & no pair partner — self-duplicate; verifier will do hashPair(h,h)
                path.push({ sibling: null });
            }
            idx = Math.floor(idx / 2);
        }

        proofs.set(userId, { path });
    }

    return { root: '0x' + root, leaves, proofs };
}

// ─── verification ─────────────────────────────────────────────────────────────

/**
 * Verifies a Merkle proof.
 * When sibling is null, the node was duplicated (odd layer) — hash with itself.
 */
export function verifyProof(
    root: string,
    proof: MerkleProofEntry,
    input: MerkleLeafInput
): boolean {
    let hash = hashLeaf(input);
    for (const step of proof.path) {
        const sibling = step.sibling ?? hash; // null → self-hash (odd layer duplication)
        hash = hashPair(hash, sibling);
    }
    return ('0x' + hash) === root;
}
