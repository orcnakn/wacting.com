import { gaussianRandom, wrapCoordinate, GRID_WIDTH, GRID_HEIGHT } from '../utils/brownian.js';
import { SpatialIndex } from './spatial_index.js';
import { notificationQueue } from '../services/notification_worker.js';
import { PrismaClient } from '@prisma/client';
import wc from 'which-country';

const prisma = new PrismaClient();

export interface IconState {
    id: string;
    userId: string;
    x: number;
    y: number;
    vx: number;       // velocity x
    vy: number;       // velocity y
    baseSpeed: number; // 1.0 default, modified by WAC balance
    size: number;
    wacBalance: number; // WAC balance — drives aura/visibility
    exploreMode: number; // 0=City, 1=Country, 2=World
    // Campaign data — drives icon movement speed, color, and slogan display
    campaignSpeed?: number;  // 0-1, default 0.5 = 75% of reference speed
    campaignColor?: string;  // hex color from campaign iconColor
    campaignSlogan?: string; // slogan text from campaign
    restrictedContinents?: string[];
    restrictedCountries?: string[];
    restrictedCities?: string[];
    // Memory Cache for Country Visit metrics
    currentCountry?: string;
}

export function tickMovement(icon: IconState, dt: number): void {
    // 0=City, 1=Country, 2=World — base step sizes (reference: mock_95 speed)
    let stepSize = 0.5; // Default City
    if (icon.exploreMode === 1) {
        stepSize = 2.0;
    } else if (icon.exploreMode === 2) {
        stepSize = 10.0;
    }

    // Apply campaign speed: campaignSpeed=0.5 → 75% of reference step, campaignSpeed=0 → stays in place
    const cSpeed = icon.campaignSpeed ?? 0.5;
    stepSize = stepSize * (cSpeed / 0.5) * 0.75;

    icon.vx = (Math.random() - 0.5) * stepSize;
    icon.vy = (Math.random() - 0.5) * stepSize;

    const newX = icon.x + icon.vx;
    const newY = icon.y + icon.vy;

    // Check Geographic Boundary Restrictions (Continents, Countries, Cities)
    const hasRestrictions = (icon.restrictedContinents?.length ?? 0) > 0 ||
        (icon.restrictedCountries?.length ?? 0) > 0 ||
        (icon.restrictedCities?.length ?? 0) > 0;

    if (hasRestrictions) {
        // Here we do a reverse coordinate map:
        // x (-180 to 180) -> longitude
        // y (90 to -90) -> latitude (Note: in Cartesian visually +y is down, but map +y is up in Lat, let's keep raw value mapping simple)
        const countryIso3 = wc([newX, newY]); // which-country takes [lng, lat]

        let allowed = true;
        if (icon.restrictedCountries && icon.restrictedCountries.length > 0) {
            // Basic naive string match for now; UI sends 'Germany', wc returns 'DEU'. 
            // Production needs a mapping. For the prototype we assume Elastic bouncing to show mechanics.
            const hitBoundary = Math.random() < 0.05; // Simulate country border hit 
            if (hitBoundary) allowed = false;
        }

        if (!allowed) {
            icon.vx *= -1;
            icon.vy *= -1;
            icon.x += icon.vx;
            icon.y += icon.vy;
        } else {
            icon.x = wrapCoordinate(newX, GRID_WIDTH);
            icon.y = wrapCoordinate(newY, GRID_HEIGHT);
        }
    } else {
        // World boundary wrapping (toroidal topology)
        icon.x = wrapCoordinate(newX, GRID_WIDTH);
        icon.y = wrapCoordinate(newY, GRID_HEIGHT);
    }

    // Asynchronous Tracker Logic (To be connected to Prisma)
    const newCountryIso = wc([icon.x, icon.y]);
    if (newCountryIso && newCountryIso !== icon.currentCountry) {
        icon.currentCountry = newCountryIso;

        // We do this non-blocking
        if (!icon.id.startsWith('mock')) {
            prisma.iconCountryVisit.upsert({
                where: {
                    iconId_countryName: {
                        iconId: icon.id,
                        countryName: newCountryIso
                    }
                },
                update: {
                    visitCount: { increment: 1 }
                },
                create: {
                    iconId: icon.id,
                    countryName: newCountryIso,
                    visitCount: 1
                }
            }).catch(err => console.error(`Failed to track country visit for ${icon.id}:`, err));
        }
    }
}

export class MovementEngine {
    public icons: Map<string, IconState> = new Map();
    public spatialIndex: SpatialIndex = new SpatialIndex();
    private tickInterval: NodeJS.Timeout | null = null;
    public tickCount: number = 0;

    start(): void {
        // Run at 1 Hz (1000ms intervals)
        if (!this.tickInterval) {
            this.tickInterval = setInterval(() => this.tick(1.0), 1000);
        }
    }

    stop(): void {
        if (this.tickInterval) {
            clearInterval(this.tickInterval);
            this.tickInterval = null;
        }
    }

    public tick(dt: number = 0.2): void {
        // 1. Update all icon positions
        for (const icon of this.icons.values()) {
            tickMovement(icon, dt);
        }

        // 2. Rebuild spatial index allowing for rapid viewport query
        this.spatialIndex.rebuild(this.icons);

        this.tickCount++;
    }
}
