import { describe, it, expect } from 'vitest';
import { buildMerkleTree, verifyProof } from '../../src/engine/merkle_builder.js';

const EPOCH = 20260307;

const sampleInputs = [
    { userId: 'alice', epoch: EPOCH, rewardWac: 1.5 },
    { userId: 'bob', epoch: EPOCH, rewardWac: 3.0 },
    { userId: 'carol', epoch: EPOCH, rewardWac: 1.0 },
];

describe('buildMerkleTree', () => {
    it('returns a non-empty root for valid inputs', () => {
        const { root } = buildMerkleTree(sampleInputs);
        expect(root).toMatch(/^0x[0-9a-f]{64}$/);
    });

    it('returns a zero root for empty inputs', () => {
        const { root } = buildMerkleTree([]);
        expect(root).toBe('0x' + '0'.repeat(64));
        expect(buildMerkleTree([]).leaves).toHaveLength(0);
    });

    it('is deterministic — same inputs produce same root', () => {
        const r1 = buildMerkleTree(sampleInputs);
        const r2 = buildMerkleTree(sampleInputs);
        expect(r1.root).toBe(r2.root);
    });

    it('produces different roots for different inputs', () => {
        const r1 = buildMerkleTree(sampleInputs);
        const r2 = buildMerkleTree([{ userId: 'dave', epoch: EPOCH, rewardWac: 6.0 }]);
        expect(r1.root).not.toBe(r2.root);
    });

    it('generates a proof for every input userId', () => {
        const { proofs } = buildMerkleTree(sampleInputs);
        for (const input of sampleInputs) {
            expect(proofs.has(input.userId)).toBe(true);
        }
    });

    it('handles a single leaf (degenerate tree)', () => {
        const inputs = [{ userId: 'only', epoch: EPOCH, rewardWac: 41.0 }];
        const { root, proofs } = buildMerkleTree(inputs);
        expect(root).toMatch(/^0x[0-9a-f]{64}$/);
        expect(proofs.get('only')!.path).toHaveLength(0); // no siblings
    });
});

describe('verifyProof', () => {
    it('verifies a valid proof for each leaf (including odd-positioned carol)', () => {
        const { root, proofs } = buildMerkleTree(sampleInputs);
        for (const input of sampleInputs) {
            const proof = proofs.get(input.userId)!;
            expect(verifyProof(root, proof, input)).toBe(true);
        }
    });

    it('verifies proof for a 2-leaf tree', () => {
        const inputs = [
            { userId: 'u1', epoch: EPOCH, rewardWac: 1.0 },
            { userId: 'u2', epoch: EPOCH, rewardWac: 3.0 },
        ];
        const { root, proofs } = buildMerkleTree(inputs);
        for (const input of inputs) {
            expect(verifyProof(root, proofs.get(input.userId)!, input)).toBe(true);
        }
    });

    it('rejects a tampered rewardWac value', () => {
        const { root, proofs } = buildMerkleTree(sampleInputs);
        const tampered = { ...sampleInputs[0]!, rewardWac: 999.0 };
        const proof = proofs.get('alice')!;
        expect(verifyProof(root, proof, tampered)).toBe(false);
    });

    it('rejects a proof for a wrong root', () => {
        const { proofs } = buildMerkleTree(sampleInputs);
        const fakeRoot = '0x' + 'ab'.repeat(32);
        const proof = proofs.get('alice')!;
        expect(verifyProof(fakeRoot, proof, sampleInputs[0]!)).toBe(false);
    });
});
