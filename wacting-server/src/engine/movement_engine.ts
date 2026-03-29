import { gaussianRandom, wrapCoordinate, GRID_WIDTH, GRID_HEIGHT } from '../utils/brownian.js';
import { SpatialIndex } from './spatial_index.js';
import { notificationQueue } from '../services/notification_worker.js';
import { PrismaClient } from '@prisma/client';
import wc from 'which-country';

const prisma = new PrismaClient();

// ── Country name → ISO3 mapping (Natural Earth GeoJSON names → which-country ISO3) ──
const NAME_TO_ISO3: Record<string, string> = {
    'Afghanistan':'AFG','Albania':'ALB','Algeria':'DZA','Andorra':'AND','Angola':'AGO',
    'Antigua and Barbuda':'ATG','Argentina':'ARG','Armenia':'ARM','Australia':'AUS',
    'Austria':'AUT','Azerbaijan':'AZE','Bahamas':'BHS','Bahrain':'BHR','Bangladesh':'BGD',
    'Barbados':'BRB','Belarus':'BLR','Belgium':'BEL','Belize':'BLZ','Benin':'BEN',
    'Bhutan':'BTN','Bolivia':'BOL','Bosnia and Herzegovina':'BIH','Botswana':'BWA',
    'Brazil':'BRA','Brunei':'BRN','Bulgaria':'BGR','Burkina Faso':'BFA','Burundi':'BDI',
    'Cambodia':'KHM','Cameroon':'CMR','Canada':'CAN','Cape Verde':'CPV',
    'Central African Republic':'CAF','Chad':'TCD','Chile':'CHL','China':'CHN',
    'Colombia':'COL','Comoros':'COM','Congo':'COG','Costa Rica':'CRI','Croatia':'HRV',
    'Cuba':'CUB','Cyprus':'CYP','Czech Republic':'CZE','Czechia':'CZE',
    'Democratic Republic of the Congo':'COD','Denmark':'DNK','Djibouti':'DJI',
    'Dominica':'DMA','Dominican Republic':'DOM','East Timor':'TLS','Timor-Leste':'TLS',
    'Ecuador':'ECU','Egypt':'EGY','El Salvador':'SLV','Equatorial Guinea':'GNQ',
    'Eritrea':'ERI','Estonia':'EST','Eswatini':'SWZ','Swaziland':'SWZ','Ethiopia':'ETH',
    'Fiji':'FJI','Finland':'FIN','France':'FRA','Gabon':'GAB','Gambia':'GMB',
    'Georgia':'GEO','Germany':'DEU','Ghana':'GHA','Greece':'GRC','Greenland':'GRL',
    'Grenada':'GRD','Guatemala':'GTM','Guinea':'GIN','Guinea-Bissau':'GNB','Guyana':'GUY',
    'Haiti':'HTI','Honduras':'HND','Hungary':'HUN','Iceland':'ISL','India':'IND',
    'Indonesia':'IDN','Iran':'IRN','Iraq':'IRQ','Ireland':'IRL','Israel':'ISR',
    'Italy':'ITA','Ivory Coast':'CIV',"Côte d'Ivoire":'CIV','Jamaica':'JAM','Japan':'JPN',
    'Jordan':'JOR','Kazakhstan':'KAZ','Kenya':'KEN','Kiribati':'KIR','Kosovo':'XKX',
    'Kuwait':'KWT','Kyrgyzstan':'KGZ','Laos':'LAO','Latvia':'LVA','Lebanon':'LBN',
    'Lesotho':'LSO','Liberia':'LBR','Libya':'LBY','Liechtenstein':'LIE','Lithuania':'LTU',
    'Luxembourg':'LUX','Madagascar':'MDG','Malawi':'MWI','Malaysia':'MYS','Maldives':'MDV',
    'Mali':'MLI','Malta':'MLT','Marshall Islands':'MHL','Mauritania':'MRT','Mauritius':'MUS',
    'Mexico':'MEX','Micronesia':'FSM','Moldova':'MDA','Monaco':'MCO','Mongolia':'MNG',
    'Montenegro':'MNE','Morocco':'MAR','Mozambique':'MOZ','Myanmar':'MMR','Namibia':'NAM',
    'Nauru':'NRU','Nepal':'NPL','Netherlands':'NLD','New Caledonia':'NCL',
    'New Zealand':'NZL','Nicaragua':'NIC','Niger':'NER','Nigeria':'NGA',
    'North Korea':'PRK','North Macedonia':'MKD','Norway':'NOR','Oman':'OMN',
    'Pakistan':'PAK','Palau':'PLW','Palestine':'PSE','Panama':'PAN',
    'Papua New Guinea':'PNG','Paraguay':'PRY','Peru':'PER','Philippines':'PHL',
    'Poland':'POL','Portugal':'PRT','Puerto Rico':'PRI','Qatar':'QAT','Romania':'ROU',
    'Russia':'RUS','Rwanda':'RWA','Saint Kitts and Nevis':'KNA','Saint Lucia':'LCA',
    'Saint Vincent and the Grenadines':'VCT','Samoa':'WSM','San Marino':'SMR',
    'Saudi Arabia':'SAU','Senegal':'SEN','Serbia':'SRB','Republic of Serbia':'SRB',
    'Sierra Leone':'SLE','Singapore':'SGP','Slovakia':'SVK','Slovenia':'SVN',
    'Solomon Islands':'SLB','Somalia':'SOM','Somaliland':'SOM','South Africa':'ZAF',
    'South Korea':'KOR','South Sudan':'SSD','Spain':'ESP','Sri Lanka':'LKA',
    'Sudan':'SDN','Suriname':'SUR','Sweden':'SWE','Switzerland':'CHE','Syria':'SYR',
    'Taiwan':'TWN','Tajikistan':'TJK','Tanzania':'TZA','United Republic of Tanzania':'TZA',
    'Thailand':'THA','Togo':'TGO','Tonga':'TON','Trinidad and Tobago':'TTO',
    'Tunisia':'TUN','Turkey':'TUR','Turkmenistan':'TKM','Tuvalu':'TUV','Uganda':'UGA',
    'Ukraine':'UKR','United Arab Emirates':'ARE','United Kingdom':'GBR',
    'United States of America':'USA','United States':'USA','Uruguay':'URY',
    'Uzbekistan':'UZB','Vanuatu':'VUT','Vatican':'VAT','Venezuela':'VEN',
    'Vietnam':'VNM','Western Sahara':'ESH','Yemen':'YEM','Zambia':'ZMB','Zimbabwe':'ZWE',
    'Falkland Islands':'FLK','French Guiana':'GUF','Antarctica':'ATA',
    'Northern Cyprus':'CYP','Republic of the Congo':'COG',
};

// Continent → ISO3 set (for continent-level restrictions)
const CONTINENT_ISO3: Record<string, Set<string>> = {};
const CONTINENT_COUNTRIES: Record<string, string[]> = {
    'Europe': ['Albania','Andorra','Austria','Belarus','Belgium','Bosnia and Herzegovina','Bulgaria','Croatia','Cyprus','Czech Republic','Czechia','Denmark','Estonia','Finland','France','Germany','Greece','Hungary','Iceland','Ireland','Italy','Kosovo','Latvia','Liechtenstein','Lithuania','Luxembourg','Malta','Moldova','Monaco','Montenegro','Netherlands','North Macedonia','Norway','Poland','Portugal','Romania','Russia','San Marino','Serbia','Slovakia','Slovenia','Spain','Sweden','Switzerland','Ukraine','United Kingdom','Vatican','Republic of Serbia','Northern Cyprus'],
    'Asia': ['Afghanistan','Armenia','Azerbaijan','Bahrain','Bangladesh','Bhutan','Brunei','Cambodia','China','East Timor','Timor-Leste','Georgia','India','Indonesia','Iran','Iraq','Israel','Japan','Jordan','Kazakhstan','Kuwait','Kyrgyzstan','Laos','Lebanon','Malaysia','Maldives','Mongolia','Myanmar','Nepal','North Korea','Oman','Pakistan','Palestine','Philippines','Qatar','Saudi Arabia','Singapore','South Korea','Sri Lanka','Syria','Taiwan','Tajikistan','Thailand','Turkey','Turkmenistan','United Arab Emirates','Uzbekistan','Vietnam','Yemen'],
    'Africa': ['Algeria','Angola','Benin','Botswana','Burkina Faso','Burundi','Cameroon','Cape Verde','Central African Republic','Chad','Comoros','Congo','Democratic Republic of the Congo','Republic of the Congo','Ivory Coast','Djibouti','Egypt','Equatorial Guinea','Eritrea','Eswatini','Ethiopia','Gabon','Gambia','Ghana','Guinea','Guinea-Bissau','Kenya','Lesotho','Liberia','Libya','Madagascar','Malawi','Mali','Mauritania','Mauritius','Morocco','Mozambique','Namibia','Niger','Nigeria','Rwanda','Senegal','Sierra Leone','Somalia','Somaliland','South Africa','South Sudan','Sudan','Tanzania','Togo','Tunisia','Uganda','Zambia','Zimbabwe','Western Sahara','United Republic of Tanzania','Swaziland'],
    'North America': ['Antigua and Barbuda','Bahamas','Barbados','Belize','Canada','Costa Rica','Cuba','Dominica','Dominican Republic','El Salvador','Grenada','Guatemala','Haiti','Honduras','Jamaica','Mexico','Nicaragua','Panama','Saint Kitts and Nevis','Saint Lucia','Saint Vincent and the Grenadines','Trinidad and Tobago','United States of America','United States','Puerto Rico','Greenland'],
    'South America': ['Argentina','Bolivia','Brazil','Chile','Colombia','Ecuador','Guyana','Paraguay','Peru','Suriname','Uruguay','Venezuela','French Guiana','Falkland Islands'],
    'Oceania': ['Australia','Fiji','Kiribati','Marshall Islands','Micronesia','Nauru','New Zealand','Palau','Papua New Guinea','Samoa','Solomon Islands','Tonga','Tuvalu','Vanuatu','New Caledonia'],
};

// Build continent → ISO3 sets at startup
for (const [continent, countries] of Object.entries(CONTINENT_COUNTRIES)) {
    const isoSet = new Set<string>();
    for (const name of countries) {
        const iso = NAME_TO_ISO3[name];
        if (iso) isoSet.add(iso);
    }
    CONTINENT_ISO3[continent] = isoSet;
}

/** Convert restriction arrays (country names, continent names) → Set of allowed ISO3 codes */
export function buildAllowedIso3(icon: IconState): Set<string> | null {
    const hasRestrictions = (icon.restrictedContinents?.length ?? 0) > 0 ||
        (icon.restrictedCountries?.length ?? 0) > 0;

    if (!hasRestrictions) return null; // null = all land allowed

    const allowed = new Set<string>();

    // Add all countries from restricted continents
    if (icon.restrictedContinents) {
        for (const cont of icon.restrictedContinents) {
            const isoSet = CONTINENT_ISO3[cont];
            if (isoSet) {
                for (const iso of isoSet) allowed.add(iso);
            }
        }
    }

    // Add individual restricted countries
    if (icon.restrictedCountries) {
        for (const name of icon.restrictedCountries) {
            // Try as country name first, then as ISO3 directly
            const iso = NAME_TO_ISO3[name] ?? name;
            allowed.add(iso);
        }
    }

    return allowed.size > 0 ? allowed : null;
}

export interface IconState {
    id: string;
    userId: string;
    x: number;
    y: number;
    vx: number;       // velocity x
    vy: number;       // velocity y
    baseSpeed: number; // 1.0 default, modified by WAC balance
    size: number;
    wacBalance: number; // WAC balance — drives visibility
    exploreMode: number; // 0=City, 1=Country, 2=World
    // Campaign data — drives icon movement speed, color, and slogan display
    campaignSpeed?: number;  // 0-1: 1x=1000km/s, 0.6x=5s/1000km, 0=stationary
    campaignColor?: string;  // hex color from campaign iconColor
    campaignSlogan?: string; // slogan text from campaign
    // Campaign leader pinned position (grid coords, null = not pinned)
    pinnedX?: number | null;
    pinnedY?: number | null;
    isCampaignLeader?: boolean;
    isEmergency?: boolean;          // Emergency campaign flag (red + radio wave)
    emergencyAreaM2?: number;       // Emergency logo area in m²
    stanceType?: string;            // SUPPORT | REFORM | PROTEST | EMERGENCY
    campaignId?: string;            // Campaign ID for detail lookups
    // Level system — drives visibility hierarchy on the map
    level?: number;                  // Total campaign level (follower + year + WAC)
    widthMeters?: number;            // Physical sign width in meters
    heightMeters?: number;           // Physical sign height in meters
    restrictedContinents?: string[];
    restrictedCountries?: string[];
    restrictedCities?: string[];
    // Precomputed allowed ISO3 set (null = all land)
    _allowedIso3?: Set<string> | null;
    // Memory Cache for Country Visit metrics
    currentCountry?: string;
}

// ── Speed formula ──────────────────────────────────────────────────────────
// 1x = 1000 km/s → max speed.  Each 0.1x decrease adds 1 second.
// seconds_per_1000km = 1 + (1 - speed) * 10
// At 1x: 1s, 0.6x: 5s, 0.2x: 9s, 0x: stationary
// Earth circumference ≈ 40 075 km, grid width = 715 px → 1 px ≈ 56.05 km
const EARTH_CIRC_KM = 40_075;
const KM_PER_PIXEL = EARTH_CIRC_KM / GRID_WIDTH;  // ≈ 56.05

function campaignStepSize(speed: number): number {
    if (speed <= 0) return 0;
    const secondsPer1000km = 1 + (1 - speed) * 10;
    // pixels per second
    return (1000 / KM_PER_PIXEL) / secondsPer1000km;
}

export function tickMovement(icon: IconState, dt: number): void {
    const cSpeed = icon.campaignSpeed ?? 0.5;

    // Campaign leader with pinned position and speed 0 → stay pinned
    if (icon.pinnedX != null && icon.pinnedY != null && cSpeed <= 0) {
        icon.x = icon.pinnedX;
        icon.y = icon.pinnedY;
        icon.vx = 0;
        icon.vy = 0;
        return;
    }

    // Calculate step size using new km-based formula
    let stepSize = campaignStepSize(cSpeed);

    icon.vx = (Math.random() - 0.5) * stepSize;
    icon.vy = (Math.random() - 0.5) * stepSize;

    const newX = icon.x + icon.vx;
    const newY = icon.y + icon.vy;

    // Convert grid coords → lng/lat for geographic checks
    const newLng = (newX / GRID_WIDTH) * 360 - 180;
    const newLat = 90 - (newY / GRID_HEIGHT) * 180;

    // Check which country the new position falls in
    const countryIso3 = wc([newLng, newLat]);

    // Build allowed set (cached on first use)
    if (icon._allowedIso3 === undefined) {
        icon._allowedIso3 = buildAllowedIso3(icon);
    }

    if (icon._allowedIso3 !== null) {
        // Has restrictions: only allow movement within allowed countries
        if (countryIso3 && icon._allowedIso3.has(countryIso3)) {
            icon.x = wrapCoordinate(newX, GRID_WIDTH);
            icon.y = Math.max(0, Math.min(newY, GRID_HEIGHT)); // clamp Y (latitude doesn't wrap)
        }
        // If not in allowed set (ocean or wrong country), icon stays in place
    } else {
        // No restrictions: allow all land
        if (countryIso3 != null) {
            icon.x = wrapCoordinate(newX, GRID_WIDTH);
            icon.y = Math.max(0, Math.min(newY, GRID_HEIGHT)); // clamp Y
        }
        // If ocean, icon stays in place
    }

    // Asynchronous Tracker Logic
    const currentLng = (icon.x / GRID_WIDTH) * 360 - 180;
    const currentLat = 90 - (icon.y / GRID_HEIGHT) * 180;
    const newCountryIso = wc([currentLng, currentLat]);
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
