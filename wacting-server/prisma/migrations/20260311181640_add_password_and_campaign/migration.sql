-- AlterTable
ALTER TABLE "User" ADD COLUMN     "passwordHash" TEXT;

-- CreateTable
CREATE TABLE "Campaign" (
    "id" TEXT NOT NULL,
    "leaderId" TEXT NOT NULL,
    "title" VARCHAR(100) NOT NULL,
    "slogan" VARCHAR(100) NOT NULL,
    "description" TEXT,
    "videoUrl" TEXT,
    "iconColor" VARCHAR(7) NOT NULL,
    "iconShape" INTEGER NOT NULL DEFAULT 0,
    "instagramUrl" TEXT,
    "twitterUrl" TEXT,
    "facebookUrl" TEXT,
    "tiktokUrl" TEXT,
    "websiteUrl" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Campaign_pkey" PRIMARY KEY ("id")
);

-- AddForeignKey
ALTER TABLE "Campaign" ADD CONSTRAINT "Campaign_leaderId_fkey" FOREIGN KEY ("leaderId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
