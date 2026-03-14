-- AlterEnum
ALTER TYPE "TxType" ADD VALUE 'WAC_WELCOME_BONUS';
ALTER TYPE "TxType" ADD VALUE 'WAC_CAMPAIGN_STAKE';
ALTER TYPE "TxType" ADD VALUE 'WAC_CAMPAIGN_RETURN';
ALTER TYPE "TxType" ADD VALUE 'WAC_BURN';
ALTER TYPE "TxType" ADD VALUE 'WAC_DEV_FEE';

-- AlterTable: Campaign - add WAC staking and ranking fields
ALTER TABLE "Campaign" ADD COLUMN "dailyRankingPoints" DECIMAL(30,6) NOT NULL DEFAULT 0,
ADD COLUMN "totalWacStaked" DECIMAL(30,6) NOT NULL DEFAULT 0;

-- AlterTable: CampaignMember - add individual staked WAC
ALTER TABLE "CampaignMember" ADD COLUMN "stakedWac" DECIMAL(30,6) NOT NULL DEFAULT 0;

-- AlterTable: RacPool - change from targetUserId to targetCampaignId
ALTER TABLE "RacPool" DROP CONSTRAINT "RacPool_targetUserId_fkey";
DROP INDEX "RacPool_targetUserId_key";
ALTER TABLE "RacPool" DROP COLUMN "targetUserId",
ADD COLUMN "targetCampaignId" TEXT NOT NULL;

-- AlterTable: Transaction - add chain integrity fields
ALTER TABLE "Transaction" ADD COLUMN "blockNumber" INTEGER,
ADD COLUMN "campaignId" TEXT,
ADD COLUMN "ipHash" TEXT,
ADD COLUMN "prevTxHash" TEXT,
ADD COLUMN "txHash" TEXT;

-- AlterTable: Treasury - split balance into burn + dev
ALTER TABLE "Treasury" DROP COLUMN "balance",
ADD COLUMN "burnedTotal" DECIMAL(30,6) NOT NULL DEFAULT 0,
ADD COLUMN "devBalance" DECIMAL(30,6) NOT NULL DEFAULT 0;

-- CreateIndex
CREATE UNIQUE INDEX "RacPool_targetCampaignId_key" ON "RacPool"("targetCampaignId");
CREATE UNIQUE INDEX "Transaction_blockNumber_key" ON "Transaction"("blockNumber");
CREATE UNIQUE INDEX "Transaction_txHash_key" ON "Transaction"("txHash");

-- AddForeignKey
ALTER TABLE "RacPool" ADD CONSTRAINT "RacPool_targetCampaignId_fkey" FOREIGN KEY ("targetCampaignId") REFERENCES "Campaign"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
