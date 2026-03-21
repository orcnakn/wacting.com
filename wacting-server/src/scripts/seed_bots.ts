// @ts-nocheck
/**
 * seed_bots.ts — 1000 Bot User Seeder (v7)
 *
 * Creates 1000 realistic bot users with 500 campaigns across all 4 stance types
 * (SUPPORT, REFORM, PROTEST, EMERGENCY), social graph, WAC/RAC economy, polls, votes, DMs.
 *
 * Run: npx tsx src/scripts/seed_bots.ts
 */

import { PrismaClient, Prisma } from '@prisma/client';
import bcrypt from 'bcryptjs';
import { recordChainedTransaction } from '../engine/chain_engine.js';

const prisma = new PrismaClient();
const BOT_PASSWORD_HASH = await bcrypt.hash('WactingBot2026!', 10);

// Grid dimensions — must match GRID_WIDTH/GRID_HEIGHT in brownian.ts
const GRID_WIDTH = 715;
const GRID_HEIGHT = 714;

function lngToGridX(lng: number): number {
  return (lng + 180) / 360 * GRID_WIDTH;
}
function latToGridY(lat: number): number {
  return (90 - lat) / 180 * GRID_HEIGHT;
}

// ─── World Cities ────────────────────────────────────────────────────────────
const WORLD_CITIES = [
  // US
  { city: 'New York', x: -74.006, y: 40.7128 },
  { city: 'Los Angeles', x: -118.2437, y: 34.0522 },
  { city: 'Chicago', x: -87.6298, y: 41.8781 },
  { city: 'Houston', x: -95.3698, y: 29.7604 },
  { city: 'Phoenix', x: -112.074, y: 33.4484 },
  { city: 'San Francisco', x: -122.4194, y: 37.7749 },
  { city: 'Seattle', x: -122.3321, y: 47.6062 },
  { city: 'Denver', x: -104.9903, y: 39.7392 },
  { city: 'Miami', x: -80.1918, y: 25.7617 },
  { city: 'Atlanta', x: -84.388, y: 33.749 },
  { city: 'Boston', x: -71.0589, y: 42.3601 },
  { city: 'Dallas', x: -96.797, y: 32.7767 },
  { city: 'Washington DC', x: -77.0369, y: 38.9072 },
  { city: 'Nashville', x: -86.7816, y: 36.1627 },
  { city: 'Portland', x: -122.6765, y: 45.5152 },
  // Europe
  { city: 'London', x: -0.1278, y: 51.5074 },
  { city: 'Paris', x: 2.3522, y: 48.8566 },
  { city: 'Berlin', x: 13.405, y: 52.52 },
  { city: 'Istanbul', x: 28.9784, y: 41.0082 },
  { city: 'Rome', x: 12.4964, y: 41.9028 },
  { city: 'Madrid', x: -3.7038, y: 40.4168 },
  { city: 'Amsterdam', x: 4.9041, y: 52.3676 },
  { city: 'Stockholm', x: 18.0686, y: 59.3293 },
  // Asia
  { city: 'Tokyo', x: 139.6917, y: 35.6895 },
  { city: 'Seoul', x: 126.978, y: 37.5665 },
  { city: 'Mumbai', x: 72.8777, y: 19.076 },
  { city: 'Beijing', x: 116.4074, y: 39.9042 },
  { city: 'Singapore', x: 103.8198, y: 1.3521 },
  { city: 'Dubai', x: 55.2708, y: 25.2048 },
  { city: 'Bangkok', x: 100.5018, y: 13.7563 },
  // South America
  { city: 'São Paulo', x: -46.6333, y: -23.5505 },
  { city: 'Buenos Aires', x: -58.3816, y: -34.6037 },
  { city: 'Bogotá', x: -74.0721, y: 4.711 },
  // Africa
  { city: 'Lagos', x: 3.3792, y: 6.5244 },
  { city: 'Cape Town', x: 18.4241, y: -33.9249 },
  { city: 'Nairobi', x: 36.8219, y: -1.2921 },
  // Oceania
  { city: 'Sydney', x: 151.2093, y: -33.8688 },
  { city: 'Melbourne', x: 144.9631, y: -37.8136 },
];

// ─── Icon Colors ─────────────────────────────────────────────────────────────
const COLORS = [
  '#2C3E50', '#E74C3C', '#3498DB', '#2ECC71', '#F39C12', '#9B59B6', '#1ABC9C',
  '#E67E22', '#34495E', '#16A085', '#C0392B', '#2980B9', '#27AE60', '#D35400',
  '#8E44AD', '#F1C40F', '#7F8C8D', '#00BCD4', '#FF5722', '#4CAF50', '#FF9800',
  '#795548', '#607D8B', '#E91E63', '#009688', '#673AB7', '#CDDC39', '#FF4081',
  '#00E676', '#AA00FF',
];

// ─── Bot Names (1000) ────────────────────────────────────────────────────────

interface BotProfile {
  name: string;
  slogan: string;
  category: string;
  colorHex: string;
  shapeIndex: number;
  exploreMode: number;
  cityIdx: number;
}

function generateBots(): BotProfile[] {
  const firstNames = [
    'James', 'Maria', 'David', 'Sarah', 'Marcus', 'Emily', 'Robert', 'Jessica',
    'Michael', 'Ashley', 'Chris', 'Amanda', 'Daniel', 'Samantha', 'Matthew',
    'Lauren', 'Andrew', 'Rachel', 'Joshua', 'Megan', 'Brandon', 'Stephanie',
    'Kevin', 'Nicole', 'Justin', 'Amber', 'Ryan', 'Kayla', 'Tyler', 'Brittany',
    'Nathan', 'Danielle', 'Cody', 'Chelsea', 'Kyle', 'Heather', 'Patrick',
    'Tiffany', 'Sean', 'Christina', 'Derek', 'Melissa', 'Dustin', 'Monica',
    'Trevor', 'Diana', 'Chad', 'Courtney', 'Brett', 'Lindsey', 'Alex', 'Priya',
    'Jake', 'Suki', 'Omar', 'Emma', 'Raj', 'Sophie', 'Liam', 'Aisha',
    'Ben', 'Maya', 'Ethan', 'Zara', 'Noah', 'Chloe', 'Aaron', 'Grace',
    'Dylan', 'Lily', 'Connor', 'Ava', 'Lucas', 'Hailey', 'Ian', 'Olivia',
    'Adrian', 'Natalie', 'Vincent', 'Isabel', 'Felix', 'Jasmine', 'Maxwell',
    'Kira', 'Philip', 'Tanya', 'Oscar', 'Fiona', 'Miles', 'Leah', 'Gavin',
    'Elise', 'Tony', 'Serena', 'Carlos', 'Jordan', 'Tyrone', 'Tessa',
    'Andre', 'Crystal', 'Jamal', 'Brianna', 'Zoe', 'Sebastian', 'Luna',
    'Theo', 'Aurora', 'Julian', 'Ivy', 'Dorian', 'Celeste', 'August',
    'Freya', 'Leonardo', 'Violet', 'Atticus', 'Dahlia', 'Hugo', 'Aria',
    'Jasper', 'Willow', 'Orion', 'Penelope', 'Roman', 'Elara', 'Beckett',
    'Juniper', 'Ezra', 'Ophelia', 'Tobias', 'Clementine', 'Arlo', 'Rosalie',
    'Rashad', 'Alicia', 'Cedric', 'Shanice', 'Xavier', 'Kiara', 'Dante',
    'Aaliyah', 'Lamar', 'Ebony', 'Tiana', 'Kendrick', 'Monique', 'Dwayne',
    'Leticia', 'Rosa', 'Walter', 'Helen', 'Arthur', 'Carla', 'Eugene',
    'Bernice', 'Vernon', 'Alma', 'Howard', 'Loretta', 'Stanley', 'Mabel',
    'Ernest', 'Juanita', 'Simone', 'Damien', 'Asha', 'Giovanni', 'Nadia',
    'Ravi', 'Kai', 'Naomi', 'Devon', 'Sierra', 'Elijah', 'Leo', 'Finn',
    'Jade', 'Sofia', 'Amir', 'Brooklyn', 'Hana', 'Quinn', 'Paloma',
  ];

  const lastNames = [
    'Wilson', 'Garcia', 'Chen', 'Johnson', 'Brown', 'Kim', 'Taylor', 'Martinez',
    'Davis', 'Anderson', 'Lee', 'Thomas', 'Jackson', 'White', 'Harris',
    'Martin', 'Thompson', 'Moore', 'Clark', 'Lewis', 'Robinson', 'Walker',
    'Young', 'Allen', 'King', 'Wright', 'Scott', 'Green', 'Baker', 'Adams',
    'Nelson', 'Hill', 'Campbell', 'Mitchell', 'Roberts', 'Carter', 'Phillips',
    'Evans', 'Turner', 'Torres', 'Parker', 'Collins', 'Edwards', 'Stewart',
    'Sanchez', 'Morris', 'Rogers', 'Reed', 'Cook', 'Morgan', 'Rivera',
    'Patel', 'Morrison', 'Nakamura', 'Hassan', 'Krishnan', 'OBrien',
    'Washington', 'Goldstein', 'Rodriguez', 'Park', 'Ahmed', 'Williams',
    'Bennett', 'Murphy', 'Liu', 'Cooper', 'Chang', 'Bailey', 'Foster',
    'Nguyen', 'Hoffman', 'Santos', 'Reyes', 'Cruz', 'Wu', 'Flores',
    'Zhang', 'Grant', 'Yamamoto', 'Frost', 'Volkov', 'Ramirez', 'Shaw',
    'Tucker', 'Romero', 'Price', 'Hart', 'Ortega', 'Spencer', 'Tran',
    'Wells', 'Vargas', 'Knight', 'Roy', 'Pearson', 'Costa', 'Chandler',
    'Whitmore', 'Fontaine', 'Brennan', 'Montenegro', 'Caldwell', 'Prescott',
    'Valentine', 'Beaumont', 'Drake', 'Archer', 'Blackwood', 'Jennings',
    'Harlow', 'McCormick', 'Nightingale', 'Rhodes', 'Bell', 'Kane',
    'Sutherland', 'Dunn', 'Gray', 'Hernandez', 'Franklin', 'Stone',
    'Padilla', 'Jenkins', 'Moretti', 'Okonkwo', 'Swenson', 'Rosario',
    'Tanaka', 'Kowalski', 'Chambers', 'Jimenez', 'Petersen', 'Holloway',
    'Santiago', 'Goldman', 'Cervantes', 'Johansson', 'Abubakar', 'Zimmerman',
    'Gutierrez', 'Okamura', 'Christensen', 'Tsosie', 'Beauchamp', 'Fujimoto',
    'Delgado', 'Villanueva', 'Magnusson', 'Bautista', 'Montoya', 'Ibrahim',
    'Richter', 'Petrov', 'Mendes', 'Bassett', 'Hayes', 'Reddy', 'Bianchi',
    'Singh', 'Kapoor', 'Sayed', 'Diallo', 'El-Amin', 'Ayala', 'Nash',
  ];

  const slogans = [
    'Planet Earth First', 'Go Green or Go Home', 'Save Our Oceans', 'Trees Are Life',
    'Code Is Poetry', 'Debug The World', 'Open Source Hero', 'AI For Good',
    'Ball Is Life', 'Champion Mindset', 'Game Day Ready', 'Never Stop Running',
    'Art Speaks Louder', 'Create Every Day', 'Paint The World', 'Music Is Life',
    'Community Strong', 'Together We Rise', 'Neighbors First', 'Local Hero',
    'Vote Every Time', 'Democracy Matters', 'Civic Duty First', 'Transparency Now',
    'Ship Or Die', 'Move Fast Build', 'Startup Life', 'Founder Mode On',
    'Study Hard Play Hard', 'Future Leader', 'Campus Life', 'Knowledge Seeker',
    'Clean Air Now', 'Solar Powered Soul', 'Earth Defender', 'Nature Over Profit',
    'Hack The Planet', 'Data Driven', 'Privacy Matters', 'Build Break Learn',
    'Train Hard Win Big', 'Born To Compete', 'Rise And Grind', 'Beast Mode On',
    'Dance Like Nobody', 'Stage Is My Home', 'Write Your Story', 'Poetry In Motion',
    'Grassroots Power', 'People Over Profit', 'Serve Others First', 'United We Stand',
    'Hold Power Accountable', 'Reform Not Revolt', 'Policy Wonk', 'Free Press Defender',
    'Build Something Great', 'Disrupt Everything', 'Growth Hacker', 'Innovation Engine',
    'Eco Warrior', 'Zero Waste Advocate', 'Protect Wildlife', 'Sustainable Future',
    'Full Stack Dreamer', 'Always Be Shipping', 'Machine Learning', 'DevOps Culture',
    'Heart Of A Champion', 'Team Player Always', 'Grind And Shine', 'Speed Demon',
    'Color My World', 'Jazz Soul Living', 'Street Art King', 'Digital Art Pro',
    'Food For All', 'Shelter Everyone', 'Education First', 'Volunteer Spirit',
    'Liberty And Justice', 'Equal Rights Now', 'Healthcare For All', 'Infrastructure Now',
    'Revenue First', 'Lean Startup', 'Bootstrap King', 'Scale Or Fail',
    'Degree Loading', 'Lab Rat Life', 'Thesis Writing', 'Finals Survivor',
    'Ocean Guardian', 'Climate Action Now', 'Carbon Neutral Life', 'Rewild The Planet',
    'Quantum Ready', 'IoT Explorer', 'Edge Computing', 'Serverless Fan',
    'Victory Or Nothing', 'Iron Will', 'Marathon Runner', 'Gym Warrior',
    'Rhythm And Blues', 'Canvas Dreams', 'Indie Film Maker', 'Stand Up Comedy',
  ];

  const categories = ['env', 'tech', 'sports', 'arts', 'community', 'politics', 'entrepreneur', 'student'];

  const bots: BotProfile[] = [];
  for (let i = 0; i < 1000; i++) {
    const fn = firstNames[i % firstNames.length]!;
    const ln = lastNames[i % lastNames.length]!;
    // Avoid duplicate names by appending a number for repeats
    const name = i < firstNames.length * 2 ? `${fn} ${ln}` : `${fn} ${ln} ${Math.floor(i / 200) + 1}`;
    const cat = categories[i % categories.length]!;

    bots.push({
      name,
      slogan: slogans[i % slogans.length]!,
      category: cat,
      colorHex: COLORS[i % COLORS.length]!,
      shapeIndex: i % 5,
      exploreMode: i % 3,
      cityIdx: i % WORLD_CITIES.length,
    });
  }

  return bots;
}

// ─── Campaign Templates (500) ───────────────────────────────────────────────

interface CampaignTemplate {
  title: string;
  slogan: string;
  description: string;
  categoryType: string;
  iconColor: string;
  speed: number;
  stakeAmount: number;
  stanceType: string;       // SUPPORT | REFORM | PROTEST | EMERGENCY
  targetIndex?: number;     // For PROTEST: index of campaign to target
}

// Helper to generate campaign templates
function generateCampaignTemplates(): CampaignTemplate[] {
  const templates: CampaignTemplate[] = [];

  // ═══════════════════════════════════════════════════════════════════════════
  // SUPPORT campaigns (200) — 10x hype multiplier, decays -1/day
  // ═══════════════════════════════════════════════════════════════════════════
  const supportCampaigns = [
    // GLOBAL_PEACE (25)
    { title: 'Clean Ocean Initiative', slogan: 'Every Drop Counts', desc: 'Working together to remove plastic from our oceans.', cat: 'ECOLOGY_NATURE' },
    { title: 'Solar Future Alliance', slogan: 'Power The Sun', desc: 'Solar energy adoption in every household.', cat: 'TECH_FUTURE' },
    { title: 'Save The Bees Coalition', slogan: 'No Bees No Food', desc: 'Protecting pollinator habitats.', cat: 'ECOLOGY_NATURE' },
    { title: 'Rewild America', slogan: 'Nature Reclaims', desc: 'Restoring wild land to natural state.', cat: 'ECOLOGY_NATURE' },
    { title: 'Zero Waste Movement', slogan: 'Trash Is Treasure', desc: 'Building a circular economy.', cat: 'ECOLOGY_NATURE' },
    { title: 'River Restoration Project', slogan: 'Let Rivers Run', desc: 'Removing obsolete dams.', cat: 'ECOLOGY_NATURE' },
    { title: 'Urban Forest Campaign', slogan: 'City Trees Matter', desc: 'Planting trees in urban areas.', cat: 'ECOLOGY_NATURE' },
    { title: 'Coral Reef Guardians', slogan: 'Protect The Reef', desc: 'Monitoring coral reefs.', cat: 'ECOLOGY_NATURE' },
    { title: 'AI Ethics Board', slogan: 'Responsible AI', desc: 'Ethical AI guidelines.', cat: 'TECH_FUTURE' },
    { title: 'Open Source Movement', slogan: 'Code For All', desc: 'Promoting open source software.', cat: 'TECH_FUTURE' },
    { title: 'Digital Privacy Rights', slogan: 'Your Data Your Rights', desc: 'Fighting for data privacy laws.', cat: 'TECH_FUTURE' },
    { title: 'Code Education For All', slogan: 'Everyone Can Code', desc: 'CS education in every school.', cat: 'TECH_FUTURE' },
    { title: 'Youth Basketball League', slogan: 'Hoops For Hope', desc: 'Free basketball for youth.', cat: 'ENTERTAINMENT' },
    { title: 'Community Soccer Fund', slogan: 'Goal Together', desc: 'Making soccer accessible.', cat: 'ENTERTAINMENT' },
    { title: 'Street Art Collective', slogan: 'Walls Speak', desc: 'Community art across cities.', cat: 'AWARENESS' },
    { title: 'Music Education Fund', slogan: 'Every Child Plays', desc: 'Music lessons in schools.', cat: 'AWARENESS' },
    { title: 'Food Bank Network', slogan: 'No One Goes Hungry', desc: 'Nationwide food bank network.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Youth Mentorship Program', slogan: 'Guide The Future', desc: 'Mentors for at-risk youth.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Voter Registration Drive', slogan: 'Your Vote Matters', desc: 'Registering new voters.', cat: 'JUSTICE_RIGHTS' },
    { title: 'Campaign Finance Reform', slogan: 'Clean Elections', desc: 'Getting money out of politics.', cat: 'JUSTICE_RIGHTS' },
    { title: 'World Peace Initiative', slogan: 'Peace Now', desc: 'Promoting peace between nations.', cat: 'GLOBAL_PEACE' },
    { title: 'Nuclear Disarmament', slogan: 'No More Nukes', desc: 'Complete nuclear disarmament.', cat: 'GLOBAL_PEACE' },
    { title: 'Refugee Welcome Network', slogan: 'Welcome Home', desc: 'Supporting refugees worldwide.', cat: 'GLOBAL_PEACE' },
    { title: 'Anti War Coalition', slogan: 'Choose Peace', desc: 'Against armed conflicts.', cat: 'GLOBAL_PEACE' },
    { title: 'Diplomacy First Alliance', slogan: 'Talk Not Fight', desc: 'Diplomatic solutions.', cat: 'GLOBAL_PEACE' },
    // TECH_FUTURE (25)
    { title: 'Cybersecurity Alliance', slogan: 'Secure The Net', desc: 'Protecting from cyber threats.', cat: 'TECH_FUTURE' },
    { title: 'Web3 Builders Guild', slogan: 'Decentralize It', desc: 'Building decentralized web.', cat: 'TECH_FUTURE' },
    { title: 'Green Tech Initiative', slogan: 'Tech Saves Earth', desc: 'Tech for environmental challenges.', cat: 'TECH_FUTURE' },
    { title: 'Quantum Computing Club', slogan: 'Quantum Leap', desc: 'Democratizing quantum computing.', cat: 'TECH_FUTURE' },
    { title: 'Space Exploration Fund', slogan: 'Reach The Stars', desc: 'Public space exploration funding.', cat: 'TECH_FUTURE' },
    { title: 'Biotech For Good', slogan: 'Heal With Science', desc: 'Ethical biotechnology.', cat: 'TECH_FUTURE' },
    { title: 'Drone Delivery Network', slogan: 'Sky Highway', desc: 'Drone delivery for remote areas.', cat: 'TECH_FUTURE' },
    { title: 'Brain Research Initiative', slogan: 'Mind Frontier', desc: 'Neuroscience research funding.', cat: 'TECH_FUTURE' },
    { title: 'Fusion Energy Push', slogan: 'Unlimited Power', desc: 'Fusion energy research.', cat: 'TECH_FUTURE' },
    { title: 'VR Education Lab', slogan: 'Learn In VR', desc: 'VR for immersive education.', cat: 'TECH_FUTURE' },
    { title: 'Blockchain Transparency', slogan: 'Trust The Chain', desc: 'Blockchain for government.', cat: 'TECH_FUTURE' },
    { title: '3D Printing Community', slogan: 'Print The Future', desc: 'Community 3D printing labs.', cat: 'TECH_FUTURE' },
    { title: 'Satellite Internet Fund', slogan: 'Connect From Space', desc: 'Satellite internet access.', cat: 'TECH_FUTURE' },
    { title: 'Robot Ethics Forum', slogan: 'Bots With Morals', desc: 'Ethics of robotics.', cat: 'TECH_FUTURE' },
    { title: 'Digital Inclusion Project', slogan: 'Bridge The Gap', desc: 'Internet access for all.', cat: 'TECH_FUTURE' },
    { title: 'Startup Founders Hub', slogan: 'Build Bold', desc: 'Connecting startup founders.', cat: 'TECH_FUTURE' },
    { title: 'Creator Economy Fund', slogan: 'Create And Earn', desc: 'Fair monetization for creators.', cat: 'TECH_FUTURE' },
    { title: 'STEM For Girls', slogan: 'She Can Code', desc: 'Girls in STEM education.', cat: 'TECH_FUTURE' },
    { title: 'Free Textbooks Project', slogan: 'Knowledge Is Free', desc: 'Open source textbooks.', cat: 'TECH_FUTURE' },
    { title: 'Youth Coding Bootcamp', slogan: 'Debug The Future', desc: 'Free coding for teens.', cat: 'TECH_FUTURE' },
    { title: 'AI Art Collective', slogan: 'Machine Muse', desc: 'AI-generated art exploration.', cat: 'TECH_FUTURE' },
    { title: 'IoT Home Safety', slogan: 'Smart And Safe', desc: 'Affordable IoT for homes.', cat: 'TECH_FUTURE' },
    { title: 'Autonomous Vehicle Safety', slogan: 'Drive Safe Auto', desc: 'Self-driving standards.', cat: 'TECH_FUTURE' },
    { title: 'Biometric Privacy', slogan: 'My Face My Data', desc: 'Biometric data protection.', cat: 'TECH_FUTURE' },
    { title: 'Quantum Security Alliance', slogan: 'Post Quantum Safe', desc: 'Post-quantum cryptography.', cat: 'TECH_FUTURE' },
    // ECOLOGY_NATURE (25)
    { title: 'Sustainable Farming Fund', slogan: 'Feed The Future', desc: 'Regenerative agriculture.', cat: 'ECOLOGY_NATURE' },
    { title: 'Clean Water Initiative', slogan: 'Water Is Life', desc: 'Clean water for all.', cat: 'ECOLOGY_NATURE' },
    { title: 'Climate Research Fund', slogan: 'Science Not Silence', desc: 'Independent climate research.', cat: 'ECOLOGY_NATURE' },
    { title: 'Clean Energy Research', slogan: 'Power Tomorrow', desc: 'Next-gen clean energy.', cat: 'ECOLOGY_NATURE' },
    { title: 'Ocean Research Center', slogan: 'Deep Blue Discovery', desc: 'Deep ocean ecosystems.', cat: 'ECOLOGY_NATURE' },
    { title: 'Electric Vehicle Fund', slogan: 'Drive Electric', desc: 'EV adoption and charging.', cat: 'ECOLOGY_NATURE' },
    { title: 'Recycling Innovation', slogan: 'Rethink Waste', desc: 'New recycling tech.', cat: 'ECOLOGY_NATURE' },
    { title: 'Vertical Farming Project', slogan: 'Grow Up', desc: 'Urban vertical farming.', cat: 'ECOLOGY_NATURE' },
    { title: 'Lab Grown Meat Fund', slogan: 'Meat Without Harm', desc: 'Sustainable protein.', cat: 'ECOLOGY_NATURE' },
    { title: 'Carbon Capture Tech', slogan: 'Suck It Up', desc: 'Carbon capture development.', cat: 'ECOLOGY_NATURE' },
    { title: 'Plastic Free Oceans', slogan: 'No More Plastic', desc: 'Banning single-use plastics.', cat: 'ECOLOGY_NATURE' },
    { title: 'Bee Highway Project', slogan: 'Buzzing Corridors', desc: 'Pollinator pathways.', cat: 'ECOLOGY_NATURE' },
    { title: 'Wetland Restoration', slogan: 'Marshes Matter', desc: 'Restoring wetlands.', cat: 'ECOLOGY_NATURE' },
    { title: 'Composting Campaign', slogan: 'Rot Is Right', desc: 'Community composting.', cat: 'ECOLOGY_NATURE' },
    { title: 'Mangrove Planting', slogan: 'Roots Against Storms', desc: 'Planting mangroves.', cat: 'ECOLOGY_NATURE' },
    { title: 'Wildlife Corridor Fund', slogan: 'Let Them Roam', desc: 'Safe wildlife crossings.', cat: 'ECOLOGY_NATURE' },
    { title: 'Soil Health Project', slogan: 'Ground Up Change', desc: 'Regenerative soil methods.', cat: 'ECOLOGY_NATURE' },
    { title: 'Rainwater Harvesting', slogan: 'Catch The Rain', desc: 'Rainwater collection.', cat: 'ECOLOGY_NATURE' },
    { title: 'Green Rooftop Alliance', slogan: 'Gardens Above', desc: 'Green rooftop spaces.', cat: 'ECOLOGY_NATURE' },
    { title: 'Clean Beach Campaign', slogan: 'Shores Deserve Better', desc: 'Beach cleanup programs.', cat: 'ECOLOGY_NATURE' },
    { title: 'Reforestation Army', slogan: 'Plant A Billion', desc: 'Massive reforestation.', cat: 'ECOLOGY_NATURE' },
    { title: 'Glacier Protection Fund', slogan: 'Freeze The Melt', desc: 'Protecting glaciers.', cat: 'ECOLOGY_NATURE' },
    { title: 'Dark Sky Initiative', slogan: 'See The Stars', desc: 'Reducing light pollution.', cat: 'ECOLOGY_NATURE' },
    { title: 'Invasive Species Control', slogan: 'Native Only', desc: 'Removing invasive species.', cat: 'ECOLOGY_NATURE' },
    { title: 'Green Startup Fund', slogan: 'Eco Innovation', desc: 'Funding green startups.', cat: 'ECOLOGY_NATURE' },
    // SOLIDARITY_RELIEF (25)
    { title: 'Homeless Shelter Project', slogan: 'Roof For Everyone', desc: 'Transitional housing.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Senior Care Alliance', slogan: 'Honor Our Elders', desc: 'Care for isolated seniors.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Community Health Center', slogan: 'Health For All', desc: 'Affordable healthcare.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Disaster Relief Corps', slogan: 'Ready To Help', desc: 'Rapid disaster response.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Women In Business', slogan: 'Lead With Power', desc: 'Supporting women entrepreneurs.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Minority Business Grant', slogan: 'Equal Opportunity', desc: 'Grants for minority businesses.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Trade School Revival', slogan: 'Skills Not Debt', desc: 'Trade education revival.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Cooperative Business Model', slogan: 'Own Together', desc: 'Worker-owned cooperatives.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Veteran Entrepreneurs', slogan: 'Service To Business', desc: 'Veterans starting businesses.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Social Enterprise Network', slogan: 'Profit With Purpose', desc: 'Social problem-solving businesses.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Micro Lending Circle', slogan: 'Small Loans Big Dreams', desc: 'Community micro-lending.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Food Truck Alliance', slogan: 'Street Eats Unite', desc: 'Supporting food truck owners.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Campus Mental Health', slogan: 'Mind Matters', desc: 'Mental health on campuses.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'After School Programs', slogan: 'Keep Kids Safe', desc: 'After-school activities.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'College Access Alliance', slogan: 'Doors Wide Open', desc: 'First-gen college support.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'School Lunch Reform', slogan: 'Healthy Kids', desc: 'Nutritious school meals.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Mental Health Awareness', slogan: 'Break The Stigma', desc: 'Ending mental health stigma.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Addiction Recovery Network', slogan: 'One Day At A Time', desc: 'Addiction recovery support.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Free Clinic Network', slogan: 'Care Without Cost', desc: 'Free health clinics.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Blood Donation Drive', slogan: 'Give Blood Save Lives', desc: 'Community blood drives.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Elder Care Volunteers', slogan: 'Age With Dignity', desc: 'Volunteer elderly care.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Nutrition Education Hub', slogan: 'Eat Smart', desc: 'Teaching nutrition skills.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Immigrant Welcome Network', slogan: 'Welcome Home', desc: 'Supporting immigrants.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Bilingual Education', slogan: 'Two Tongues', desc: 'Bilingual programs.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Cultural Exchange Program', slogan: 'Share Cultures', desc: 'International exchange.', cat: 'SOLIDARITY_RELIEF' },
    // ENTERTAINMENT + AWARENESS (25)
    { title: 'Skatepark Alliance', slogan: 'Skate Free', desc: 'Free skateparks.', cat: 'ENTERTAINMENT' },
    { title: 'Girls Sports Coalition', slogan: 'She Plays', desc: 'Equal sports for girls.', cat: 'ENTERTAINMENT' },
    { title: 'Esports Academy', slogan: 'Game On', desc: 'Gaming in schools.', cat: 'ENTERTAINMENT' },
    { title: 'Marathon For Charity', slogan: 'Run For Cause', desc: 'Charity marathons.', cat: 'ENTERTAINMENT' },
    { title: 'Community Theater', slogan: 'Stage For All', desc: 'Free theater productions.', cat: 'ENTERTAINMENT' },
    { title: 'Poetry Slam Movement', slogan: 'Words Have Power', desc: 'Poetry slam events.', cat: 'ENTERTAINMENT' },
    { title: 'Film Festival Fund', slogan: 'Stories Matter', desc: 'Independent film support.', cat: 'ENTERTAINMENT' },
    { title: 'Dance Revolution', slogan: 'Move Together', desc: 'Free dance classes.', cat: 'ENTERTAINMENT' },
    { title: 'Digital Arts Hub', slogan: 'Create Digital', desc: 'Digital art skills.', cat: 'ENTERTAINMENT' },
    { title: 'Public Library Revival', slogan: 'Read And Grow', desc: 'Modernizing libraries.', cat: 'AWARENESS' },
    { title: 'Heritage Preservation', slogan: 'Honor The Past', desc: 'Preserving history.', cat: 'AWARENESS' },
    { title: 'Museum Free Days', slogan: 'Art For Everyone', desc: 'Free museum admission.', cat: 'AWARENESS' },
    { title: 'Documentary Film Fund', slogan: 'Real Stories', desc: 'Important documentaries.', cat: 'AWARENESS' },
    { title: 'Book Club Network', slogan: 'Read Together', desc: 'Community book clubs.', cat: 'AWARENESS' },
    { title: 'Photography Workshop', slogan: 'Capture Moments', desc: 'Free photo workshops.', cat: 'AWARENESS' },
    { title: 'Local News Revival', slogan: 'Truth Nearby', desc: 'Supporting local journalism.', cat: 'AWARENESS' },
    { title: 'Podcast For Change', slogan: 'Voices Matter', desc: 'Amplifying voices.', cat: 'AWARENESS' },
    { title: 'Language Revival Project', slogan: 'Save Tongues', desc: 'Preserving languages.', cat: 'AWARENESS' },
    { title: 'Arts In Schools Fund', slogan: 'Create Express', desc: 'Arts education budgets.', cat: 'AWARENESS' },
    { title: 'Indie Game Developers', slogan: 'Play Different', desc: 'Supporting indie games.', cat: 'ENTERTAINMENT' },
    { title: 'Music Festival Grant', slogan: 'Sound Of Summer', desc: 'Community music festivals.', cat: 'ENTERTAINMENT' },
    { title: 'Open Mic Revolution', slogan: 'Your Stage', desc: 'Free open mic nights.', cat: 'ENTERTAINMENT' },
    { title: 'Comic Book Literacy', slogan: 'Read In Color', desc: 'Comics for literacy.', cat: 'AWARENESS' },
    { title: 'Graffiti Art Program', slogan: 'Color The City', desc: 'Legal graffiti walls.', cat: 'ENTERTAINMENT' },
    { title: 'Public Radio Fund', slogan: 'Free Airwaves', desc: 'Independent public radio.', cat: 'AWARENESS' },
    // ECONOMY_LABOR (25)
    { title: 'Small Biz Alliance', slogan: 'Local First', desc: 'Protecting small businesses.', cat: 'ECONOMY_LABOR' },
    { title: 'Freelancer Protection', slogan: 'Fair Pay Fair Work', desc: 'Freelancer protections.', cat: 'ECONOMY_LABOR' },
    { title: 'Rural Internet Access', slogan: 'Connect Every Town', desc: 'Rural broadband.', cat: 'ECONOMY_LABOR' },
    { title: 'Gig Workers United', slogan: 'Fair Gig Economy', desc: 'Better gig conditions.', cat: 'ECONOMY_LABOR' },
    { title: 'Digital Nomad Alliance', slogan: 'Work Anywhere', desc: 'Remote work rights.', cat: 'ECONOMY_LABOR' },
    { title: 'Workers Rights Movement', slogan: 'Labor Deserves More', desc: 'Better wages for all.', cat: 'ECONOMY_LABOR' },
    { title: 'Fair Housing Alliance', slogan: 'Home For Everyone', desc: 'Fighting housing discrimination.', cat: 'ECONOMY_LABOR' },
    { title: 'Tenant Rights Coalition', slogan: 'Housing Is A Right', desc: 'Protecting renters.', cat: 'ECONOMY_LABOR' },
    { title: 'Teacher Pay Campaign', slogan: 'Pay Our Teachers', desc: 'Competitive teacher salaries.', cat: 'ECONOMY_LABOR' },
    { title: 'Universal Basic Income', slogan: 'UBI For All', desc: 'Guaranteed basic income.', cat: 'ECONOMY_LABOR' },
    { title: 'Minimum Wage Raise', slogan: 'Living Wage Now', desc: 'Raising minimum wage.', cat: 'ECONOMY_LABOR' },
    { title: 'Union Power Revival', slogan: 'Organize Together', desc: 'Strengthening labor unions.', cat: 'ECONOMY_LABOR' },
    { title: 'Student Debt Relief', slogan: 'Free To Learn', desc: 'Student loan reform.', cat: 'ECONOMY_LABOR' },
    { title: 'Affordable Childcare', slogan: 'Care For Kids', desc: 'Universal childcare.', cat: 'ECONOMY_LABOR' },
    { title: 'Pension Protection Fund', slogan: 'Retire Safe', desc: 'Protecting pensions.', cat: 'ECONOMY_LABOR' },
    { title: 'Fair Trade Alliance', slogan: 'Trade With Justice', desc: 'Fair trade practices.', cat: 'ECONOMY_LABOR' },
    { title: 'Anti Monopoly Watch', slogan: 'Break Big Tech', desc: 'Fighting monopolies.', cat: 'ECONOMY_LABOR' },
    { title: 'Cooperative Housing', slogan: 'Live Together', desc: 'Community housing.', cat: 'ECONOMY_LABOR' },
    { title: 'Green Jobs Initiative', slogan: 'Work For Planet', desc: 'Green economy jobs.', cat: 'ECONOMY_LABOR' },
    { title: 'Tech Workers Union', slogan: 'Code Together', desc: 'Tech worker organizing.', cat: 'ECONOMY_LABOR' },
    { title: 'Healthcare Workers Fund', slogan: 'Heal The Healers', desc: 'Supporting healthcare workers.', cat: 'ECONOMY_LABOR' },
    { title: 'Artists Wage Fund', slogan: 'Art Pays Bills', desc: 'Fair pay for artists.', cat: 'ECONOMY_LABOR' },
    { title: 'Farm Workers Rights', slogan: 'Feed Us Fairly', desc: 'Agricultural worker rights.', cat: 'ECONOMY_LABOR' },
    { title: 'Delivery Workers Safety', slogan: 'Deliver Justice', desc: 'Delivery worker protections.', cat: 'ECONOMY_LABOR' },
    { title: 'Remote Work Standard', slogan: 'Office Optional', desc: 'Right to remote work.', cat: 'ECONOMY_LABOR' },
    // Stationary SUPPORT campaigns (25)
    { title: 'NYC Freedom Monument', slogan: 'Stand For Liberty', desc: 'Freedom monument in NYC.', cat: 'AWARENESS' },
    { title: 'LA Peace Garden', slogan: 'Grow Peace', desc: 'Peace garden in LA.', cat: 'ECOLOGY_NATURE' },
    { title: 'Chicago Memorial Wall', slogan: 'Remember Always', desc: 'Community hero memorial.', cat: 'AWARENESS' },
    { title: 'Houston Space Museum', slogan: 'Stars Within Reach', desc: 'Space exploration museum.', cat: 'TECH_FUTURE' },
    { title: 'Seattle Tech Archive', slogan: 'Digital History', desc: 'Tech revolution history.', cat: 'TECH_FUTURE' },
    { title: 'Denver Mountain Watch', slogan: 'Guard The Peaks', desc: 'Mountain ecology station.', cat: 'ECOLOGY_NATURE' },
    { title: 'Miami Coral Center', slogan: 'Reef Forever', desc: 'Coral research center.', cat: 'ECOLOGY_NATURE' },
    { title: 'Boston History Hub', slogan: 'Past Meets Present', desc: 'Interactive history center.', cat: 'AWARENESS' },
    { title: 'Portland Tree Library', slogan: 'Read Under Trees', desc: 'Outdoor forest library.', cat: 'ECOLOGY_NATURE' },
    { title: 'Nashville Sound Studio', slogan: 'Free Music Space', desc: 'Community recording studio.', cat: 'ENTERTAINMENT' },
    { title: 'Detroit Art Factory', slogan: 'Create Detroit', desc: 'Community art space.', cat: 'ENTERTAINMENT' },
    { title: 'SF Code Lab', slogan: 'Code For Free', desc: 'Free coding workspace.', cat: 'TECH_FUTURE' },
    { title: 'Austin Music Camp', slogan: 'Live Music Lives', desc: 'Live music venue.', cat: 'ENTERTAINMENT' },
    { title: 'Minneapolis Peace Center', slogan: 'Unity In Diversity', desc: 'Peace and dialogue center.', cat: 'GLOBAL_PEACE' },
    { title: 'DC Democracy Hub', slogan: 'People Power', desc: 'Civic engagement center.', cat: 'JUSTICE_RIGHTS' },
    { title: 'Honolulu Ocean Lab', slogan: 'Pacific Research', desc: 'Ocean research lab.', cat: 'ECOLOGY_NATURE' },
    { title: 'Tokyo Innovation Lab', slogan: 'Future Tokyo', desc: 'Innovation in Tokyo.', cat: 'TECH_FUTURE' },
    { title: 'London Peace Park', slogan: 'Peace In The City', desc: 'Urban peace park.', cat: 'GLOBAL_PEACE' },
    { title: 'Paris Climate Hub', slogan: 'Paris Accord Lives', desc: 'Climate action center.', cat: 'ECOLOGY_NATURE' },
    { title: 'Berlin Tech Commons', slogan: 'Free Tech Berlin', desc: 'Open tech workspace.', cat: 'TECH_FUTURE' },
    { title: 'Istanbul Bridge Project', slogan: 'Bridge East West', desc: 'Cultural bridge project.', cat: 'GLOBAL_PEACE' },
    { title: 'Sydney Harbor Guard', slogan: 'Protect The Harbor', desc: 'Harbor conservation.', cat: 'ECOLOGY_NATURE' },
    { title: 'Mumbai Hope Center', slogan: 'Hope For Mumbai', desc: 'Community hope center.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Seoul Digital Academy', slogan: 'Learn Digital', desc: 'Free digital academy.', cat: 'TECH_FUTURE' },
    { title: 'São Paulo Arts Quarter', slogan: 'Art São Paulo', desc: 'Community arts quarter.', cat: 'ENTERTAINMENT' },
  ];

  for (let i = 0; i < supportCampaigns.length; i++) {
    const c = supportCampaigns[i]!;
    const isStationary = i >= 175; // Last 25 are stationary
    templates.push({
      title: c.title,
      slogan: c.slogan,
      description: c.desc,
      categoryType: c.cat,
      iconColor: COLORS[i % COLORS.length]!,
      speed: isStationary ? 0 : 0.3 + Math.random() * 0.7,
      stakeAmount: 2 + Math.floor(Math.random() * 8),
      stanceType: 'SUPPORT',
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REFORM campaigns (125) — 0.5x→10x time multiplier, 50% exit penalty
  // ═══════════════════════════════════════════════════════════════════════════
  const reformCampaigns = [
    // JUSTICE_RIGHTS (40)
    { title: 'Term Limits Now', slogan: 'Fresh Leadership', desc: 'Congressional term limits.', cat: 'JUSTICE_RIGHTS' },
    { title: 'Police Reform Coalition', slogan: 'Serve And Protect', desc: 'Police accountability.', cat: 'JUSTICE_RIGHTS' },
    { title: 'Healthcare Access Alliance', slogan: 'Care For All', desc: 'Universal healthcare access.', cat: 'JUSTICE_RIGHTS' },
    { title: 'Education Budget Coalition', slogan: 'Fund Our Schools', desc: 'Education funding.', cat: 'JUSTICE_RIGHTS' },
    { title: 'Infrastructure Now', slogan: 'Build It Better', desc: 'Modernizing infrastructure.', cat: 'JUSTICE_RIGHTS' },
    { title: 'Transparency Watchdog', slogan: 'Open Government', desc: 'Government transparency.', cat: 'JUSTICE_RIGHTS' },
    { title: 'Equal Justice League', slogan: 'Justice For All', desc: 'Pro bono legal aid.', cat: 'JUSTICE_RIGHTS' },
    { title: 'Prison Reform Now', slogan: 'Second Chances', desc: 'Criminal justice reform.', cat: 'JUSTICE_RIGHTS' },
    { title: 'Wrongful Conviction Project', slogan: 'Free The Innocent', desc: 'Overturning wrongful convictions.', cat: 'JUSTICE_RIGHTS' },
    { title: 'Bail Reform Alliance', slogan: 'Freedom Not Fee', desc: 'Ending cash bail.', cat: 'JUSTICE_RIGHTS' },
    { title: 'LGBTQ Rights Alliance', slogan: 'Love Is Love', desc: 'LGBTQ equality.', cat: 'JUSTICE_RIGHTS' },
    { title: 'Indigenous Rights Fund', slogan: 'Honor The Land', desc: 'Indigenous sovereignty.', cat: 'JUSTICE_RIGHTS' },
    { title: 'Anti Corruption Watch', slogan: 'Clean Politics', desc: 'Exposing corruption.', cat: 'JUSTICE_RIGHTS' },
    { title: 'Child Labor Prevention', slogan: 'Kids Not Workers', desc: 'Preventing child labor.', cat: 'JUSTICE_RIGHTS' },
    { title: 'Free Speech Defense', slogan: 'Speak Freely', desc: 'Protecting free speech.', cat: 'JUSTICE_RIGHTS' },
    { title: 'Whistleblower Protection', slogan: 'Truth Tellers', desc: 'Protecting whistleblowers.', cat: 'JUSTICE_RIGHTS' },
    { title: 'Civic Engagement Project', slogan: 'Participate', desc: 'Local government participation.', cat: 'JUSTICE_RIGHTS' },
    { title: 'Disability Access Fund', slogan: 'Access For All', desc: 'Improving accessibility.', cat: 'JUSTICE_RIGHTS' },
    { title: 'School Safety Alliance', slogan: 'Safe To Learn', desc: 'School safety measures.', cat: 'JUSTICE_RIGHTS' },
    { title: 'Special Education Rights', slogan: 'Every Child Learns', desc: 'Special education funding.', cat: 'JUSTICE_RIGHTS' },
    { title: 'Age Discrimination Watch', slogan: 'Experience Matters', desc: 'Fighting age discrimination.', cat: 'JUSTICE_RIGHTS' },
    { title: 'Voting Rights Act 2.0', slogan: 'Every Vote Counts', desc: 'Strengthening voting rights.', cat: 'JUSTICE_RIGHTS' },
    { title: 'Electoral College Reform', slogan: 'Popular Vote Now', desc: 'Electoral system reform.', cat: 'JUSTICE_RIGHTS' },
    { title: 'Gerrymandering End', slogan: 'Fair Districts', desc: 'Ending gerrymandering.', cat: 'JUSTICE_RIGHTS' },
    { title: 'Judicial Reform Alliance', slogan: 'Fair Courts', desc: 'Judicial independence.', cat: 'JUSTICE_RIGHTS' },
    { title: 'Immigration Reform Now', slogan: 'Path To Citizenship', desc: 'Immigration pathway.', cat: 'JUSTICE_RIGHTS' },
    { title: 'Drug Policy Reform', slogan: 'Treatment Not Jail', desc: 'Drug decriminalization.', cat: 'JUSTICE_RIGHTS' },
    { title: 'Death Penalty Abolition', slogan: 'No State Killing', desc: 'Abolishing death penalty.', cat: 'JUSTICE_RIGHTS' },
    { title: 'Gun Safety Reform', slogan: 'Safe Not Sorry', desc: 'Common-sense gun reform.', cat: 'JUSTICE_RIGHTS' },
    { title: 'Tax Reform Alliance', slogan: 'Fair Taxes Now', desc: 'Progressive tax reform.', cat: 'JUSTICE_RIGHTS' },
    { title: 'Healthcare Reform Act', slogan: 'Fix Healthcare', desc: 'Comprehensive healthcare.', cat: 'JUSTICE_RIGHTS' },
    { title: 'Education System Reform', slogan: 'Reimagine Schools', desc: 'Education modernization.', cat: 'JUSTICE_RIGHTS' },
    { title: 'Housing Policy Reform', slogan: 'Affordable Housing', desc: 'Housing affordability.', cat: 'JUSTICE_RIGHTS' },
    { title: 'Climate Policy Reform', slogan: 'Green Legislation', desc: 'Climate legislation.', cat: 'JUSTICE_RIGHTS' },
    { title: 'Media Reform Alliance', slogan: 'Free The Press', desc: 'Media independence.', cat: 'JUSTICE_RIGHTS' },
    { title: 'Campaign Law Reform', slogan: 'Fair Campaigns', desc: 'Campaign law changes.', cat: 'JUSTICE_RIGHTS' },
    { title: 'Lobbying Transparency', slogan: 'Open Lobbying', desc: 'Transparent lobbying.', cat: 'JUSTICE_RIGHTS' },
    { title: 'Surveillance Reform', slogan: 'Stop Watching Us', desc: 'Mass surveillance limits.', cat: 'JUSTICE_RIGHTS' },
    { title: 'Net Neutrality Defense', slogan: 'Free Internet', desc: 'Protecting net neutrality.', cat: 'JUSTICE_RIGHTS' },
    { title: 'Corporate Reform Act', slogan: 'People Over Corps', desc: 'Corporate accountability.', cat: 'JUSTICE_RIGHTS' },
    // ECOLOGY_NATURE reforms (25)
    { title: 'Clean Air Reform Act', slogan: 'Breathe Clean', desc: 'Strengthening Clean Air Act.', cat: 'ECOLOGY_NATURE' },
    { title: 'Water Quality Reform', slogan: 'Pure Water Now', desc: 'Water quality standards.', cat: 'ECOLOGY_NATURE' },
    { title: 'Pesticide Ban Reform', slogan: 'No Poison', desc: 'Banning harmful pesticides.', cat: 'ECOLOGY_NATURE' },
    { title: 'Deforestation Ban', slogan: 'Save All Forests', desc: 'Ending deforestation.', cat: 'ECOLOGY_NATURE' },
    { title: 'Fishing Reform Alliance', slogan: 'Sustainable Seas', desc: 'Overfishing regulation.', cat: 'ECOLOGY_NATURE' },
    { title: 'Emission Standards Reform', slogan: 'Zero Emissions', desc: 'Stricter emission limits.', cat: 'ECOLOGY_NATURE' },
    { title: 'National Park Expansion', slogan: 'More Parks Now', desc: 'Expanding national parks.', cat: 'ECOLOGY_NATURE' },
    { title: 'Endangered Species Reform', slogan: 'Protect All Species', desc: 'Stronger protections.', cat: 'ECOLOGY_NATURE' },
    { title: 'Fracking Ban Alliance', slogan: 'No Fracking Way', desc: 'Banning hydraulic fracturing.', cat: 'ECOLOGY_NATURE' },
    { title: 'Renewable Energy Mandate', slogan: 'All Renewable', desc: '100% renewable by 2035.', cat: 'ECOLOGY_NATURE' },
    { title: 'Noise Pollution Reform', slogan: 'Quiet Cities', desc: 'Noise pollution standards.', cat: 'ECOLOGY_NATURE' },
    { title: 'Food Safety Reform', slogan: 'Safe Food Now', desc: 'Stricter food safety.', cat: 'ECOLOGY_NATURE' },
    { title: 'Plastic Tax Reform', slogan: 'Tax Plastic', desc: 'Taxing plastic production.', cat: 'ECOLOGY_NATURE' },
    { title: 'Ocean Dumping Ban', slogan: 'Clean Oceans', desc: 'Ending ocean dumping.', cat: 'ECOLOGY_NATURE' },
    { title: 'Mining Reform Act', slogan: 'Responsible Mining', desc: 'Mining accountability.', cat: 'ECOLOGY_NATURE' },
    { title: 'Animal Rights Reform', slogan: 'Animal Justice', desc: 'Animal welfare laws.', cat: 'ECOLOGY_NATURE' },
    { title: 'Chemical Safety Reform', slogan: 'Safe Chemicals', desc: 'Chemical regulations.', cat: 'ECOLOGY_NATURE' },
    { title: 'Agricultural Runoff Act', slogan: 'Clean Farms', desc: 'Farm pollution controls.', cat: 'ECOLOGY_NATURE' },
    { title: 'Green Building Standard', slogan: 'Build Green', desc: 'Green building mandates.', cat: 'ECOLOGY_NATURE' },
    { title: 'Environmental Justice Act', slogan: 'Eco Justice', desc: 'Environmental equity.', cat: 'ECOLOGY_NATURE' },
    { title: 'Wildlife Trade Ban', slogan: 'End Poaching', desc: 'Wildlife trafficking end.', cat: 'ECOLOGY_NATURE' },
    { title: 'Soil Protection Act', slogan: 'Save Our Soil', desc: 'Soil quality standards.', cat: 'ECOLOGY_NATURE' },
    { title: 'Wetland Protection Act', slogan: 'Keep Wetlands', desc: 'Wetland conservation.', cat: 'ECOLOGY_NATURE' },
    { title: 'Urban Sprawl Reform', slogan: 'Smart Growth', desc: 'Limiting urban sprawl.', cat: 'ECOLOGY_NATURE' },
    { title: 'Waste Management Reform', slogan: 'Better Waste', desc: 'Modern waste management.', cat: 'ECOLOGY_NATURE' },
    // ECONOMY_LABOR reforms (25)
    { title: 'Banking Reform Alliance', slogan: 'Break The Banks', desc: 'Financial regulation.', cat: 'ECONOMY_LABOR' },
    { title: 'Wealth Tax Initiative', slogan: 'Tax The Rich', desc: 'Wealth inequality reform.', cat: 'ECONOMY_LABOR' },
    { title: 'Stock Market Reform', slogan: 'Fair Markets', desc: 'Market transparency.', cat: 'ECONOMY_LABOR' },
    { title: 'Rent Control Coalition', slogan: 'Affordable Rent', desc: 'Rent control legislation.', cat: 'ECONOMY_LABOR' },
    { title: 'Healthcare Pricing Act', slogan: 'Fair Drug Prices', desc: 'Drug price controls.', cat: 'ECONOMY_LABOR' },
    { title: 'Overtime Pay Reform', slogan: 'Pay What Owed', desc: 'Overtime compensation.', cat: 'ECONOMY_LABOR' },
    { title: 'Maternity Leave Act', slogan: 'Parent Leave Now', desc: 'Paid parental leave.', cat: 'ECONOMY_LABOR' },
    { title: 'CEO Pay Cap Initiative', slogan: 'Cap The Top', desc: 'CEO pay ratio limits.', cat: 'ECONOMY_LABOR' },
    { title: 'Tip Workers Protection', slogan: 'Fair Tips', desc: 'Tip worker rights.', cat: 'ECONOMY_LABOR' },
    { title: 'Contractor Rights Act', slogan: 'Classify Fairly', desc: 'Worker classification.', cat: 'ECONOMY_LABOR' },
    { title: 'Equal Pay Enforcement', slogan: 'Same Work Same Pay', desc: 'Gender pay gap.', cat: 'ECONOMY_LABOR' },
    { title: 'Predatory Lending Ban', slogan: 'No More Usury', desc: 'Stopping predatory loans.', cat: 'ECONOMY_LABOR' },
    { title: 'Credit Score Reform', slogan: 'Fair Credit', desc: 'Credit system reform.', cat: 'ECONOMY_LABOR' },
    { title: 'Medical Debt Relief', slogan: 'Heal Not Bankrupt', desc: 'Medical debt reform.', cat: 'ECONOMY_LABOR' },
    { title: 'Insurance Reform Act', slogan: 'Fair Insurance', desc: 'Insurance industry reform.', cat: 'ECONOMY_LABOR' },
    { title: 'Four Day Work Week', slogan: 'Work Less Live More', desc: '4-day work standard.', cat: 'ECONOMY_LABOR' },
    { title: 'Right To Disconnect', slogan: 'Off Means Off', desc: 'After-hours work limits.', cat: 'ECONOMY_LABOR' },
    { title: 'Workplace Safety Reform', slogan: 'Safe At Work', desc: 'Stronger OSHA standards.', cat: 'ECONOMY_LABOR' },
    { title: 'Collective Bargaining Act', slogan: 'Bargain Together', desc: 'Collective bargaining.', cat: 'ECONOMY_LABOR' },
    { title: 'Pension Reform Act', slogan: 'Secure Pensions', desc: 'Pension security.', cat: 'ECONOMY_LABOR' },
    { title: 'Income Inequality Watch', slogan: 'Close The Gap', desc: 'Income gap reduction.', cat: 'ECONOMY_LABOR' },
    { title: 'Food Price Control Act', slogan: 'Affordable Food', desc: 'Food price stability.', cat: 'ECONOMY_LABOR' },
    { title: 'Energy Price Reform', slogan: 'Cheaper Energy', desc: 'Energy price regulation.', cat: 'ECONOMY_LABOR' },
    { title: 'Housing Market Reform', slogan: 'Fair Housing Market', desc: 'Housing market controls.', cat: 'ECONOMY_LABOR' },
    { title: 'Public Transit Reform', slogan: 'Free Transit', desc: 'Free public transit.', cat: 'ECONOMY_LABOR' },
    // TECH_FUTURE reforms (10)
    { title: 'AI Regulation Act', slogan: 'Control AI', desc: 'AI safety regulations.', cat: 'TECH_FUTURE' },
    { title: 'Social Media Reform', slogan: 'Fix Social Media', desc: 'Social media regulation.', cat: 'TECH_FUTURE' },
    { title: 'Algorithm Transparency', slogan: 'Open Algorithms', desc: 'Algorithm disclosure.', cat: 'TECH_FUTURE' },
    { title: 'Data Ownership Act', slogan: 'Own Your Data', desc: 'Personal data rights.', cat: 'TECH_FUTURE' },
    { title: 'Tech Monopoly Break', slogan: 'Break Big Tech', desc: 'Anti-trust enforcement.', cat: 'TECH_FUTURE' },
    { title: 'Crypto Regulation Act', slogan: 'Regulate Crypto', desc: 'Cryptocurrency rules.', cat: 'TECH_FUTURE' },
    { title: 'Deepfake Ban Act', slogan: 'No Fake Media', desc: 'Deepfake prohibition.', cat: 'TECH_FUTURE' },
    { title: 'Digital Rights Act', slogan: 'Digital Freedom', desc: 'Online rights legislation.', cat: 'TECH_FUTURE' },
    { title: 'Platform Liability Act', slogan: 'Responsible Platforms', desc: 'Platform accountability.', cat: 'TECH_FUTURE' },
    { title: 'E-Waste Reform Act', slogan: 'Recycle Tech', desc: 'Electronic waste laws.', cat: 'TECH_FUTURE' },
  ];

  for (let i = 0; i < reformCampaigns.length; i++) {
    const c = reformCampaigns[i]!;
    templates.push({
      title: c.title,
      slogan: c.slogan,
      description: c.desc,
      categoryType: c.cat,
      iconColor: COLORS[(i + 10) % COLORS.length]!,
      speed: 0.2 + Math.random() * 0.5,
      stakeAmount: 3 + Math.floor(Math.random() * 10), // Higher stakes for REFORM
      stanceType: 'REFORM',
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PROTEST campaigns (100) — 0.5 WAC + 0.5 RAC, targets a SUPPORT campaign
  // ═══════════════════════════════════════════════════════════════════════════
  const protestCampaigns = [
    { title: 'Stop Clean Ocean Greenwash', slogan: 'Real Action Not PR', desc: 'The Clean Ocean Initiative is greenwashing.', cat: 'ECOLOGY_NATURE', targetIdx: 0 },
    { title: 'Solar Scam Exposed', slogan: 'Follow The Money', desc: 'Solar Alliance uses funds poorly.', cat: 'TECH_FUTURE', targetIdx: 1 },
    { title: 'AI Ethics Is A Joke', slogan: 'Ethics Need Teeth', desc: 'AI Ethics Board has no power.', cat: 'TECH_FUTURE', targetIdx: 8 },
    { title: 'Open Source Exploitation', slogan: 'Pay The Devs', desc: 'Corps exploit open source.', cat: 'TECH_FUTURE', targetIdx: 9 },
    { title: 'Food Bank Corruption', slogan: 'Where Does It Go', desc: 'Food bank management issues.', cat: 'SOLIDARITY_RELIEF', targetIdx: 16 },
    { title: 'Voter Drive Scam', slogan: 'Fake Registrations', desc: 'Voter registration fraud.', cat: 'JUSTICE_RIGHTS', targetIdx: 18 },
    { title: 'Cybersecurity Hype', slogan: 'Fear Sells', desc: 'Creating fear for profit.', cat: 'TECH_FUTURE', targetIdx: 25 },
    { title: 'Web3 Is A Scam', slogan: 'Blockchain Bubble', desc: 'Web3 promises unfulfilled.', cat: 'TECH_FUTURE', targetIdx: 26 },
    { title: 'Space Exploration Waste', slogan: 'Fix Earth First', desc: 'Space money better on Earth.', cat: 'ECOLOGY_NATURE', targetIdx: 29 },
    { title: 'Fusion Energy Fantasy', slogan: 'Always 30 Years Away', desc: 'Fusion is a distraction.', cat: 'TECH_FUTURE', targetIdx: 33 },
    { title: 'Anti Rewild Farmers', slogan: 'Save Our Farms', desc: 'Rewilding takes farmland.', cat: 'ECONOMY_LABOR', targetIdx: 3 },
    { title: 'EV Subsidies For Rich', slogan: 'Rich Get Richer', desc: 'EV benefits only wealthy.', cat: 'ECONOMY_LABOR', targetIdx: 55 },
    { title: 'Vertical Farm Nonsense', slogan: 'Real Farms Matter', desc: 'Vertical farming not viable.', cat: 'ECOLOGY_NATURE', targetIdx: 57 },
    { title: 'Lab Meat Danger', slogan: 'Natural Food Only', desc: 'Lab meat is untested.', cat: 'ECOLOGY_NATURE', targetIdx: 58 },
    { title: 'Carbon Capture Distraction', slogan: 'Stop Emissions First', desc: 'Carbon capture delays action.', cat: 'ECOLOGY_NATURE', targetIdx: 59 },
    { title: 'Stop VR Addiction', slogan: 'Real World Matters', desc: 'VR in schools is harmful.', cat: 'AWARENESS', targetIdx: 34 },
    { title: 'Blockchain Government Bad', slogan: 'Democracy Not Code', desc: 'Blockchain in gov is risky.', cat: 'JUSTICE_RIGHTS', targetIdx: 35 },
    { title: 'Anti Drone Delivery', slogan: 'Sky Belongs To Birds', desc: 'Drones disrupt wildlife.', cat: 'ECOLOGY_NATURE', targetIdx: 31 },
    { title: 'Esports Is Not Sports', slogan: 'Move Your Body', desc: 'Gaming is not athletics.', cat: 'ENTERTAINMENT', targetIdx: 127 },
    { title: 'Digital Art Isnt Art', slogan: 'Paint For Real', desc: 'Traditional art matters.', cat: 'AWARENESS', targetIdx: 133 },
    // More protests targeting various campaigns
    { title: 'Marathon Profit Machine', slogan: 'Where Goes Money', desc: 'Charity marathons keep profits.', cat: 'AWARENESS', targetIdx: 128 },
    { title: 'Film Fund Nepotism', slogan: 'Fair Selection Now', desc: 'Festival fund plays favorites.', cat: 'ENTERTAINMENT', targetIdx: 131 },
    { title: 'Shelter Mismanagement', slogan: 'Fix Before Build', desc: 'Shelter project wastes money.', cat: 'SOLIDARITY_RELIEF', targetIdx: 100 },
    { title: 'Small Biz Alliance Scam', slogan: 'Big Business Tool', desc: 'SBA serves big corps.', cat: 'ECONOMY_LABOR', targetIdx: 150 },
    { title: 'Rural Internet Broken', slogan: 'Where Is Internet', desc: 'Rural internet never arrives.', cat: 'ECONOMY_LABOR', targetIdx: 152 },
    { title: 'Mentorship Exploitation', slogan: 'Free Labor Alert', desc: 'Mentorship = free work.', cat: 'ECONOMY_LABOR', targetIdx: 17 },
    { title: 'Bee Project Greenwash', slogan: 'Bees Need More', desc: 'Bee highway insufficient.', cat: 'ECOLOGY_NATURE', targetIdx: 61 },
    { title: 'Composting Is Useless', slogan: 'Industrial Scale Only', desc: 'Home composting has no impact.', cat: 'ECOLOGY_NATURE', targetIdx: 63 },
    { title: 'Wildlife Corridor Cost', slogan: 'Too Expensive', desc: 'Corridors cost too much.', cat: 'ECONOMY_LABOR', targetIdx: 65 },
    { title: 'Beach Cleanup Theater', slogan: 'Photo Op Only', desc: 'Cleanups are performative.', cat: 'AWARENESS', targetIdx: 69 },
    { title: 'Reforestation Wrong Trees', slogan: 'Native Trees Only', desc: 'Planting wrong species.', cat: 'ECOLOGY_NATURE', targetIdx: 70 },
    { title: 'Glacier Fund Wasted', slogan: 'Too Late For Ice', desc: 'Glacier protection impossible.', cat: 'ECOLOGY_NATURE', targetIdx: 71 },
    { title: 'Dark Sky Elitist', slogan: 'Let There Be Light', desc: 'Dark sky is anti-safety.', cat: 'AWARENESS', targetIdx: 72 },
    { title: 'Skatepark Danger', slogan: 'Kids Get Hurt', desc: 'Skateparks are unsafe.', cat: 'AWARENESS', targetIdx: 126 },
    { title: 'Library Revival Waste', slogan: 'Go Digital', desc: 'Libraries are obsolete.', cat: 'TECH_FUTURE', targetIdx: 134 },
    { title: 'Museum Funding Misuse', slogan: 'Art For Elite', desc: 'Museums serve wealthy.', cat: 'AWARENESS', targetIdx: 136 },
    { title: 'Podcast Echo Chamber', slogan: 'No Real Change', desc: 'Podcasts are slacktivism.', cat: 'AWARENESS', targetIdx: 141 },
    { title: 'Heritage Waste Money', slogan: 'Build The Future', desc: 'Heritage preservation is wasteful.', cat: 'ECONOMY_LABOR', targetIdx: 135 },
    { title: 'Trade School Classism', slogan: 'College For All', desc: 'Trade schools limit potential.', cat: 'AWARENESS', targetIdx: 106 },
    { title: 'Coop Model Fails', slogan: 'Coops Dont Scale', desc: 'Cooperatives are inefficient.', cat: 'ECONOMY_LABOR', targetIdx: 107 },
    // More diverse protests (40 more)
    { title: 'Senior Care Scandal', slogan: 'Care Not Control', desc: 'Senior care alliance neglects patients.', cat: 'SOLIDARITY_RELIEF', targetIdx: 101 },
    { title: 'Health Center Fraud', slogan: 'Count The Money', desc: 'Health center billing fraud.', cat: 'SOLIDARITY_RELIEF', targetIdx: 102 },
    { title: 'Disaster Relief Delay', slogan: 'Too Slow Always', desc: 'Relief corps too slow.', cat: 'SOLIDARITY_RELIEF', targetIdx: 103 },
    { title: 'Anti Startup Culture', slogan: 'Hustle Is Toxic', desc: 'Startup culture exploits workers.', cat: 'ECONOMY_LABOR', targetIdx: 40 },
    { title: 'Creator Fund Hoax', slogan: 'Creators Get Nothing', desc: 'Creator economy is rigged.', cat: 'ECONOMY_LABOR', targetIdx: 41 },
    { title: 'Coding Bootcamp Scam', slogan: 'No Real Jobs', desc: 'Bootcamps overpromise.', cat: 'AWARENESS', targetIdx: 44 },
    { title: 'IoT Privacy Nightmare', slogan: 'Smart Means Spied', desc: 'IoT devices spy on us.', cat: 'JUSTICE_RIGHTS', targetIdx: 46 },
    { title: 'Self Driving Danger', slogan: 'Robots Kill People', desc: 'Autonomous vehicles are unsafe.', cat: 'AWARENESS', targetIdx: 47 },
    { title: 'Biometric Surveillance', slogan: 'Face Off', desc: 'Biometrics enable surveillance.', cat: 'JUSTICE_RIGHTS', targetIdx: 48 },
    { title: 'Clean Water Lie', slogan: 'Still Dirty', desc: 'Clean water initiative fails.', cat: 'ECOLOGY_NATURE', targetIdx: 51 },
    { title: 'Electric Vehicle Hype', slogan: 'Battery Waste', desc: 'EVs create battery waste.', cat: 'ECOLOGY_NATURE', targetIdx: 55 },
    { title: 'Anti Nuclear Power', slogan: 'No Meltdowns', desc: 'Nuclear energy is too risky.', cat: 'ECOLOGY_NATURE', targetIdx: 33 },
    { title: 'Remote Work Isolation', slogan: 'Humans Need Humans', desc: 'Remote work harms mental health.', cat: 'AWARENESS', targetIdx: 154 },
    { title: 'Free Clinic Quality', slogan: 'Cheap Not Good', desc: 'Free clinics provide poor care.', cat: 'AWARENESS', targetIdx: 118 },
    { title: 'Blood Drive Privacy', slogan: 'Medical Data Risk', desc: 'Blood drives collect too much data.', cat: 'JUSTICE_RIGHTS', targetIdx: 119 },
    { title: 'Nutrition Misinformation', slogan: 'Pseudo Science', desc: 'Nutrition hub promotes fad diets.', cat: 'AWARENESS', targetIdx: 121 },
    { title: 'Immigrant Exploitation', slogan: 'Reform Not Charity', desc: 'Welcome network exploits immigrants.', cat: 'JUSTICE_RIGHTS', targetIdx: 122 },
    { title: 'Sports Girls Tokenism', slogan: 'Real Equality', desc: 'Girls coalition is tokenism.', cat: 'AWARENESS', targetIdx: 126 },
    { title: 'Poetry Is Dead', slogan: 'Nobody Reads Poems', desc: 'Poetry movement is irrelevant.', cat: 'ENTERTAINMENT', targetIdx: 130 },
    { title: 'Dance Class Problems', slogan: 'Cultural Issues', desc: 'Dance revolution appropriates culture.', cat: 'AWARENESS', targetIdx: 132 },
    // 20 more targeting REFORM campaigns (protest against reforms)
    { title: 'Anti Term Limits', slogan: 'Experience Matters', desc: 'Term limits lose expertise.', cat: 'JUSTICE_RIGHTS', targetIdx: 200 },
    { title: 'Police Funding Needed', slogan: 'Back The Blue', desc: 'Police need more funding.', cat: 'JUSTICE_RIGHTS', targetIdx: 201 },
    { title: 'Private Healthcare Works', slogan: 'Choice Not Force', desc: 'Government healthcare is bad.', cat: 'ECONOMY_LABOR', targetIdx: 202 },
    { title: 'Education Is Local', slogan: 'No Federal Control', desc: 'Federal education bad.', cat: 'JUSTICE_RIGHTS', targetIdx: 203 },
    { title: 'No Clean Air Regulations', slogan: 'Jobs Not Rules', desc: 'Clean air rules kill jobs.', cat: 'ECONOMY_LABOR', targetIdx: 240 },
    { title: 'Pesticides Feed World', slogan: 'Chemicals Save Lives', desc: 'Pesticide ban means famine.', cat: 'ECONOMY_LABOR', targetIdx: 242 },
    { title: 'Fracking Creates Jobs', slogan: 'Energy Independence', desc: 'Fracking ban hurts economy.', cat: 'ECONOMY_LABOR', targetIdx: 248 },
    { title: 'Anti AI Regulation', slogan: 'Innovation First', desc: 'AI regulation stifles progress.', cat: 'TECH_FUTURE', targetIdx: 290 },
    { title: 'Social Media Freedom', slogan: 'Dont Censor Us', desc: 'Social media regulation = censorship.', cat: 'JUSTICE_RIGHTS', targetIdx: 291 },
    { title: 'Data Ownership Impractical', slogan: 'Data Must Flow', desc: 'Data ownership kills innovation.', cat: 'TECH_FUTURE', targetIdx: 293 },
    { title: 'No Banking Reform', slogan: 'Free Markets Work', desc: 'Banking reform = socialism.', cat: 'ECONOMY_LABOR', targetIdx: 265 },
    { title: 'Anti Wealth Tax', slogan: 'Earned Not Taken', desc: 'Wealth tax is theft.', cat: 'ECONOMY_LABOR', targetIdx: 266 },
    { title: 'Anti Rent Control', slogan: 'Market Sets Prices', desc: 'Rent control reduces supply.', cat: 'ECONOMY_LABOR', targetIdx: 268 },
    { title: 'No Price Controls', slogan: 'Free Market Health', desc: 'Drug price caps reduce innovation.', cat: 'ECONOMY_LABOR', targetIdx: 269 },
    { title: 'No CEO Pay Cap', slogan: 'Pay For Performance', desc: 'CEO pay reflects value.', cat: 'ECONOMY_LABOR', targetIdx: 272 },
    { title: 'Anti 4 Day Week', slogan: 'Hard Work Wins', desc: '4-day week is lazy.', cat: 'ECONOMY_LABOR', targetIdx: 280 },
    { title: 'No Crypto Rules', slogan: 'Decentralize Everything', desc: 'Crypto regulation kills freedom.', cat: 'TECH_FUTURE', targetIdx: 295 },
    { title: 'Pro Deepfake Art', slogan: 'Art Is Free', desc: 'Deepfake ban kills creativity.', cat: 'ENTERTAINMENT', targetIdx: 296 },
    { title: 'Anti Gun Control', slogan: 'Second Amendment', desc: 'Gun reform violates rights.', cat: 'JUSTICE_RIGHTS', targetIdx: 228 },
    { title: 'No Death Penalty Ban', slogan: 'Justice Has Teeth', desc: 'Death penalty deters crime.', cat: 'JUSTICE_RIGHTS', targetIdx: 227 },
  ];

  for (let i = 0; i < protestCampaigns.length; i++) {
    const c = protestCampaigns[i]!;
    templates.push({
      title: c.title,
      slogan: c.slogan,
      description: c.desc,
      categoryType: c.cat,
      iconColor: COLORS[(i + 20) % COLORS.length]!,
      speed: 0.3 + Math.random() * 0.6,
      stakeAmount: 1 + Math.floor(Math.random() * 5),
      stanceType: 'PROTEST',
      targetIndex: c.targetIdx,
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EMERGENCY campaigns (75) — donation-based, no rewards, WAC pool for leader
  // ═══════════════════════════════════════════════════════════════════════════
  const emergencyCampaigns = [
    { title: 'Florida Hurricane Relief', slogan: 'Help Florida Now', desc: 'Emergency relief for hurricane victims.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'California Wildfire Aid', slogan: 'Fire Emergency', desc: 'Wildfire evacuation and relief.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Texas Flood Emergency', slogan: 'Texas Needs You', desc: 'Flood disaster relief.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Earthquake Response Fund', slogan: 'Quake Aid Now', desc: 'Earthquake emergency response.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Tornado Alley Relief', slogan: 'Rebuild Together', desc: 'Tornado damage recovery.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Winter Storm Emergency', slogan: 'Warmth For All', desc: 'Winter storm relief.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Volcanic Eruption Aid', slogan: 'Escape The Ash', desc: 'Volcanic disaster response.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Tsunami Recovery Fund', slogan: 'Waves Of Help', desc: 'Tsunami aftermath recovery.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Bridge Collapse Emergency', slogan: 'Bridge The Gap', desc: 'Emergency bridge repair.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Train Derailment Aid', slogan: 'Clean Up Now', desc: 'Chemical spill cleanup.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'School Shooting Fund', slogan: 'Heal Together', desc: 'Victim family support.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Hospital Fire Relief', slogan: 'Save Our Hospital', desc: 'Hospital rebuilding fund.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Pipeline Leak Emergency', slogan: 'Stop The Leak', desc: 'Pipeline spill cleanup.', cat: 'ECOLOGY_NATURE' },
    { title: 'Dam Break Response', slogan: 'Flood Aid Now', desc: 'Dam failure disaster response.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Factory Explosion Aid', slogan: 'Workers First', desc: 'Factory accident relief.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Pandemic Emergency Fund', slogan: 'Health Crisis', desc: 'Pandemic response fund.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Drought Emergency Water', slogan: 'Water Urgently', desc: 'Emergency water supply.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Power Grid Failure Aid', slogan: 'Restore Power', desc: 'Power restoration fund.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Mass Layoff Support', slogan: 'Jobs Emergency', desc: 'Support for laid-off workers.', cat: 'ECONOMY_LABOR' },
    { title: 'Housing Crisis Emergency', slogan: 'Roof Tonight', desc: 'Emergency housing fund.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Refugee Crisis Response', slogan: 'Shelter Now', desc: 'Emergency refugee housing.', cat: 'GLOBAL_PEACE' },
    { title: 'Famine Relief Fund', slogan: 'Feed The Hungry', desc: 'Emergency food distribution.', cat: 'GLOBAL_PEACE' },
    { title: 'War Refugee Aid', slogan: 'Peace And Safety', desc: 'War refugee support.', cat: 'GLOBAL_PEACE' },
    { title: 'Child Rescue Operation', slogan: 'Save The Children', desc: 'Emergency child rescue.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Medical Emergency Fund', slogan: 'Heal Now', desc: 'Emergency medical supplies.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Flint Water Crisis', slogan: 'Clean Water Now', desc: 'Water contamination emergency.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Maui Fire Recovery', slogan: 'Aloha Means Help', desc: 'Maui wildfire recovery.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'East Palestine Cleanup', slogan: 'Detox Our Town', desc: 'Chemical disaster cleanup.', cat: 'ECOLOGY_NATURE' },
    { title: 'Puerto Rico Storm Aid', slogan: 'Rebuild PR', desc: 'Hurricane recovery PR.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Louisiana Levee Crisis', slogan: 'Hold The Line', desc: 'Levee emergency repair.', cat: 'SOLIDARITY_RELIEF' },
    // 45 more emergency campaigns
    { title: 'Japan Quake Emergency', slogan: 'Stand With Japan', desc: 'Japan earthquake relief.', cat: 'GLOBAL_PEACE' },
    { title: 'Turkey Syria Aid Fund', slogan: 'Rubble To Rebuild', desc: 'Earthquake recovery fund.', cat: 'GLOBAL_PEACE' },
    { title: 'Libya Flood Emergency', slogan: 'Help Libya', desc: 'Catastrophic flood relief.', cat: 'GLOBAL_PEACE' },
    { title: 'Morocco Quake Response', slogan: 'Atlas Aid', desc: 'Earthquake response Morocco.', cat: 'GLOBAL_PEACE' },
    { title: 'Amazon Fire Emergency', slogan: 'Save Amazon', desc: 'Amazon rainforest fire.', cat: 'ECOLOGY_NATURE' },
    { title: 'Great Barrier Reef SOS', slogan: 'Reef Emergency', desc: 'Coral bleaching emergency.', cat: 'ECOLOGY_NATURE' },
    { title: 'Sahel Drought Aid', slogan: 'Water For Sahel', desc: 'Drought crisis in Sahel.', cat: 'GLOBAL_PEACE' },
    { title: 'Gaza Emergency Aid', slogan: 'Humanitarian Aid', desc: 'Emergency humanitarian relief.', cat: 'GLOBAL_PEACE' },
    { title: 'Sudan Crisis Fund', slogan: 'Sudan Needs Help', desc: 'Conflict emergency aid.', cat: 'GLOBAL_PEACE' },
    { title: 'Haiti Emergency Response', slogan: 'Haiti Strong', desc: 'Multi-crisis Haiti response.', cat: 'GLOBAL_PEACE' },
    { title: 'Bangladesh Cyclone Aid', slogan: 'Cyclone Relief', desc: 'Cyclone emergency response.', cat: 'GLOBAL_PEACE' },
    { title: 'Nepal Landslide Fund', slogan: 'Dig Together', desc: 'Landslide recovery Nepal.', cat: 'GLOBAL_PEACE' },
    { title: 'Chile Wildfire Aid', slogan: 'Apaga El Fuego', desc: 'Chile wildfire relief.', cat: 'GLOBAL_PEACE' },
    { title: 'Australia Flood Response', slogan: 'Mate Help Mate', desc: 'Australia flood emergency.', cat: 'GLOBAL_PEACE' },
    { title: 'Philippine Typhoon Aid', slogan: 'Typhoon Relief', desc: 'Typhoon emergency aid.', cat: 'GLOBAL_PEACE' },
    { title: 'India Heatwave Emergency', slogan: 'Beat The Heat', desc: 'Extreme heat crisis.', cat: 'GLOBAL_PEACE' },
    { title: 'Indonesia Volcano Aid', slogan: 'Escape The Lava', desc: 'Volcanic eruption response.', cat: 'GLOBAL_PEACE' },
    { title: 'Myanmar Crisis Aid', slogan: 'Stand With Myanmar', desc: 'Myanmar emergency relief.', cat: 'GLOBAL_PEACE' },
    { title: 'Pakistan Flood Recovery', slogan: 'Flood Survivors', desc: 'Pakistan flood aid.', cat: 'GLOBAL_PEACE' },
    { title: 'Yemen Crisis Fund', slogan: 'Yemen Needs Help', desc: 'Humanitarian crisis Yemen.', cat: 'GLOBAL_PEACE' },
    { title: 'Congo Emergency Aid', slogan: 'Help Congo', desc: 'Congo crisis response.', cat: 'GLOBAL_PEACE' },
    { title: 'Ukraine Emergency Fund', slogan: 'Slava Ukraini', desc: 'Ukraine conflict relief.', cat: 'GLOBAL_PEACE' },
    { title: 'Arctic Melt Emergency', slogan: 'Arctic SOS', desc: 'Arctic ecosystem collapse.', cat: 'ECOLOGY_NATURE' },
    { title: 'Coral Die Off Response', slogan: 'Save Coral Now', desc: 'Mass coral bleaching.', cat: 'ECOLOGY_NATURE' },
    { title: 'Pollution Emergency Zone', slogan: 'Toxic Air Alert', desc: 'Toxic pollution emergency.', cat: 'ECOLOGY_NATURE' },
    { title: 'Migrant Worker Crisis', slogan: 'Workers Emergency', desc: 'Exploited migrant workers.', cat: 'ECONOMY_LABOR' },
    { title: 'Teacher Strike Fund', slogan: 'Support Teachers', desc: 'Teacher strike support fund.', cat: 'ECONOMY_LABOR' },
    { title: 'Tech Layoff Support', slogan: 'Devs Need Help', desc: 'Tech worker layoff fund.', cat: 'ECONOMY_LABOR' },
    { title: 'Nurse Burnout Crisis', slogan: 'Help Our Nurses', desc: 'Healthcare worker support.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Homeless Winter Emergency', slogan: 'Cold Night Fund', desc: 'Winter homeless shelter.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Food Desert Emergency', slogan: 'Feed Our Block', desc: 'Food desert crisis.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Child Hunger Emergency', slogan: 'Kids Are Hungry', desc: 'Child hunger crisis fund.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Domestic Violence Shelter', slogan: 'Safe Space Now', desc: 'DV emergency shelter.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Veterans Crisis Fund', slogan: 'Honor Our Vets', desc: 'Veteran emergency support.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Mental Health Crisis Line', slogan: 'Call For Help', desc: 'Mental health hotline fund.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Opioid Crisis Response', slogan: 'End The Epidemic', desc: 'Opioid addiction emergency.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Clean Water Emergency', slogan: 'Tap Is Toxic', desc: 'Water contamination crisis.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Rare Disease Fund', slogan: 'Every Patient Matters', desc: 'Rare disease treatment fund.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Organ Transplant Fund', slogan: 'Give Life', desc: 'Transplant cost support.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Cancer Treatment Aid', slogan: 'Fight Cancer Now', desc: 'Cancer treatment fund.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Disability Emergency Fund', slogan: 'Access Now', desc: 'Disability support crisis.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Elder Abuse Emergency', slogan: 'Protect Elders', desc: 'Elder abuse response.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Youth Suicide Prevention', slogan: 'Save Young Lives', desc: 'Youth crisis intervention.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Disaster Pet Rescue', slogan: 'Save All Lives', desc: 'Animal rescue in disasters.', cat: 'SOLIDARITY_RELIEF' },
    { title: 'Emergency School Repair', slogan: 'Fix Our Schools', desc: 'Damaged school repair fund.', cat: 'SOLIDARITY_RELIEF' },
  ];

  for (let i = 0; i < emergencyCampaigns.length; i++) {
    const c = emergencyCampaigns[i]!;
    templates.push({
      title: c.title,
      slogan: c.slogan,
      description: c.desc,
      categoryType: c.cat,
      iconColor: COLORS[(i + 5) % COLORS.length]!,
      speed: 0, // Emergency campaigns are stationary
      stakeAmount: 5 + Math.floor(Math.random() * 15), // Higher donations
      stanceType: 'EMERGENCY',
    });
  }

  return templates;
}

// ─── Direct Message Templates ───────────────────────────────────────────────
const DM_TEMPLATES = [
  'Hey! Love your campaign, keep it up!',
  'Just joined your campaign, excited to contribute!',
  'What do you think about the latest poll?',
  'Great work on the initiative!',
  'Want to collaborate on something?',
  'Your WAC strategy is impressive!',
  'Thanks for the follow! Let\'s connect.',
  'How much WAC are you staking?',
  'I think we should rally more supporters.',
  'The platform is really growing fast!',
  'Nice slogan! Very creative.',
  'Are you going to vote on the community poll?',
  'I\'m thinking about starting my own campaign.',
  'The WAC economy is really interesting.',
  'I deposited more WAC today, feeling bullish!',
  'RAC protests are heating up!',
  'Should we join forces against that campaign?',
  'The leaderboard is getting competitive.',
  'I love the map visualization feature.',
  'What\'s your strategy for earning more WAC?',
  'The reform campaigns are really gaining traction!',
  'Emergency fund raised so much WAC!',
  'Which reform campaign should I join?',
  'The protest movement is growing stronger.',
  'Have you checked the hype multiplier decay?',
  'My reform multiplier just went up to 3x!',
  'How long have you been in that reform campaign?',
  'The emergency donation fund is amazing.',
  'I think we need more protest campaigns.',
  'Support campaigns have the best early returns.',
];

// ─── Poll Templates ──────────────────────────────────────────────────────────
const POLL_TEMPLATES = [
  { title: 'What should be our top priority?', options: ['Membership growth', 'Campaign awareness', 'Community events', 'Social media push'] },
  { title: 'Best time for community meetings?', options: ['Weekday evenings', 'Weekend mornings', 'Weekend afternoons'] },
  { title: 'Should we increase campaign stake?', options: ['Yes, double it', 'Small increase', 'Keep it the same', 'Decrease it'] },
  { title: 'Next campaign theme?', options: ['Education', 'Environment', 'Technology', 'Community'] },
  { title: 'How should we use campaign funds?', options: ['Marketing', 'Events', 'Charity donation', 'Platform development'] },
  { title: 'Vote on new campaign slogan', options: ['Together We Rise', 'Power To The People', 'Change Starts Here'] },
  { title: 'Rate our campaign progress', options: ['Excellent', 'Good', 'Needs improvement', 'Poor'] },
  { title: 'Best outreach strategy?', options: ['Social media', 'Word of mouth', 'Events', 'Partnerships'] },
  { title: 'How often should we poll?', options: ['Weekly', 'Bi-weekly', 'Monthly'] },
  { title: 'Should we protest a bigger campaign?', options: ['Yes lets fight', 'No stay focused', 'Need more members first'] },
];

// ─── Initial Multipliers ─────────────────────────────────────────────────────
const INITIAL_MULTIPLIER: Record<string, number> = {
  SUPPORT: 10.0,
  REFORM: 0.5,
  PROTEST: 1.0,
  EMERGENCY: 1.0,
};

// ─── Seeder Logic ────────────────────────────────────────────────────────────

async function seedBots() {
  console.log('🤖 Starting Wacting Bot Seeder v7...\n');

  // Idempotency check
  const existingBots = await prisma.user.count({ where: { isBot: true } });
  if (existingBots >= 1000) {
    console.log(`✅ ${existingBots} bots already exist. Skipping seed.`);
    return;
  }
  if (existingBots > 0) {
    console.log(`⚠ Found ${existingBots} partial bots. Cleaning up...`);
    const botIds = (await prisma.user.findMany({ where: { isBot: true }, select: { id: true } })).map(u => u.id);
    await prisma.pollVote.deleteMany({ where: { voterId: { in: botIds } } });
    await prisma.directMessage.deleteMany({ where: { OR: [{ senderId: { in: botIds } }, { receiverId: { in: botIds } }] } });
    await prisma.follow.deleteMany({ where: { OR: [{ followerId: { in: botIds } }, { followingId: { in: botIds } }] } });
    await prisma.notification.deleteMany({ where: { userId: { in: botIds } } });
    const botCampaigns = (await prisma.campaign.findMany({ where: { leaderId: { in: botIds } }, select: { id: true } })).map(c => c.id);
    if (botCampaigns.length > 0) {
      await prisma.pollVote.deleteMany({ where: { poll: { campaignId: { in: botCampaigns } } } });
      await (prisma as any).pollOption.deleteMany({ where: { poll: { campaignId: { in: botCampaigns } } } });
      await (prisma as any).campaignPoll.deleteMany({ where: { campaignId: { in: botCampaigns } } });
      await prisma.racPoolParticipant.deleteMany({ where: { pool: { targetCampaignId: { in: botCampaigns } } } });
      await prisma.racPool.deleteMany({ where: { targetCampaignId: { in: botCampaigns } } });
      await (prisma as any).campaignMember.deleteMany({ where: { campaignId: { in: botCampaigns } } });
      await (prisma as any).campaignHistory.deleteMany({ where: { campaignId: { in: botCampaigns } } });
      await prisma.campaign.deleteMany({ where: { id: { in: botCampaigns } } });
    }
    await (prisma as any).campaignMember.deleteMany({ where: { userId: { in: botIds } } });
    await prisma.transaction.deleteMany({ where: { userId: { in: botIds } } });
    await prisma.userRac.deleteMany({ where: { userId: { in: botIds } } });
    await prisma.userWac.deleteMany({ where: { userId: { in: botIds } } });
    await prisma.icon.deleteMany({ where: { userId: { in: botIds } } });
    await prisma.devNote.deleteMany({ where: { userId: { in: botIds } } });
    await prisma.user.deleteMany({ where: { isBot: true } });
    console.log('🗑 Cleaned up partial bots.\n');
  }

  const bots = generateBots();
  const campaignTemplates = generateCampaignTemplates();
  const createdUserIds: string[] = [];

  // ══════════════════════════════════════════════════════════════════════════
  // PHASE A: Create 1000 Users
  // ══════════════════════════════════════════════════════════════════════════
  console.log('📦 Phase A: Creating 1000 bot users...');
  for (let i = 0; i < bots.length; i++) {
    const bot = bots[i]!;
    const city = WORLD_CITIES[bot.cityIdx]!;
    const emailName = bot.name.toLowerCase().replace(/[^a-z0-9]/g, '.').replace(/\.+/g, '.').replace(/^\.+|\.+$/g, '');
    const email = `bot${i}@wacting.com`;

    const user = await prisma.user.create({
      data: {
        email,
        passwordHash: BOT_PASSWORD_HASH,
        slogan: bot.name,
        description: `${bot.slogan} — ${bot.category.toUpperCase()} advocate from ${city.city}`,
        emailVerified: true,
        isBot: true,
        icon: {
          create: {
            slogan: bot.slogan.substring(0, 50),
            colorHex: bot.colorHex,
            shapeIndex: bot.shapeIndex,
            lastKnownX: lngToGridX(city.x) + (Math.random() - 0.5) * 2,
            lastKnownY: latToGridY(city.y) + (Math.random() - 0.5) * 2,
            exploreMode: bot.exploreMode,
          },
        },
        wac: {
          create: {
            wacBalance: new Prisma.Decimal('200.000000'),
            isActive: true,
          },
        },
      },
    });

    await prisma.$transaction(async (tx) => {
      await recordChainedTransaction(tx, {
        userId: user.id,
        amount: '200.000000',
        type: 'WAC_WELCOME_BONUS' as any,
        note: `Welcome bonus: 200 WAC (Bot #${i + 1})`,
      });
    });

    createdUserIds.push(user.id);
    if ((i + 1) % 100 === 0) console.log(`   ✓ ${i + 1}/1000 users created`);
  }
  console.log('   ✅ All 1000 users created.\n');

  // ══════════════════════════════════════════════════════════════════════════
  // PHASE B: Create 500 Campaigns (200 SUPPORT, 125 REFORM, 100 PROTEST, 75 EMERGENCY)
  // ══════════════════════════════════════════════════════════════════════════
  console.log('🏴 Phase B: Creating 500 campaigns...');
  const campaignIds: string[] = [];
  const campaignLeaders: Map<string, string> = new Map();
  const campaignStances: Map<string, string> = new Map();

  for (let i = 0; i < campaignTemplates.length; i++) {
    const tmpl = campaignTemplates[i]!;
    // Pick a leader — distribute across all users
    const leaderIdx = (i * 2) % createdUserIds.length;
    const leaderId = createdUserIds[leaderIdx]!;
    const stakeAmount = new Prisma.Decimal(tmpl.stakeAmount.toFixed(6));
    const multiplier = INITIAL_MULTIPLIER[tmpl.stanceType] ?? 1.0;

    // For PROTEST, find the target campaign
    let targetCampaignId: string | undefined;
    if (tmpl.stanceType === 'PROTEST' && tmpl.targetIndex !== undefined) {
      // targetIndex refers to the index in our template list
      // Only reference already-created campaigns
      if (tmpl.targetIndex < campaignIds.length) {
        targetCampaignId = campaignIds[tmpl.targetIndex];
      } else {
        // Fallback: target a random earlier campaign
        targetCampaignId = campaignIds[i % Math.max(1, campaignIds.length)];
      }
    }

    try {
      const campaign = await prisma.$transaction(async (tx) => {
        await tx.userWac.update({
          where: { userId: leaderId },
          data: {
            wacBalance: { decrement: stakeAmount },
            balanceUpdatedAt: new Date(),
          },
        });

        const createData: any = {
          leaderId,
          title: tmpl.title,
          slogan: tmpl.slogan,
          description: tmpl.description,
          iconColor: tmpl.iconColor,
          iconShape: leaderIdx % 5,
          speed: tmpl.speed,
          totalWacStaked: stakeAmount,
          stanceType: tmpl.stanceType,
          categoryType: tmpl.categoryType,
        };

        if (tmpl.stanceType === 'EMERGENCY') {
          createData.emergencyWacPool = stakeAmount;
          // Emergency campaigns expire in 30 days
          createData.emergencyExpiresAt = new Date(Date.now() + 30 * 86400000);
        }

        if (targetCampaignId) {
          createData.targetCampaignId = targetCampaignId;
        }

        const c = await (tx as any).campaign.create({ data: createData });

        // Leader joins with correct multiplier
        // For REFORM campaigns, set varied joinedAt to test time multipliers
        const joinedAt = tmpl.stanceType === 'REFORM'
          ? new Date(Date.now() - (7 + Math.floor(Math.random() * 180)) * 86400000) // 7-187 days ago
          : new Date();

        await (tx as any).campaignMember.create({
          data: {
            campaignId: c.id,
            userId: leaderId,
            stakedWac: stakeAmount,
            multiplier,
            joinedAt,
          },
        });

        await recordChainedTransaction(tx, {
          userId: leaderId,
          amount: stakeAmount,
          type: 'WAC_CAMPAIGN_STAKE' as any,
          note: `Campaign created: "${tmpl.title}" [${tmpl.stanceType}] — staked ${tmpl.stakeAmount} WAC`,
          campaignId: c.id,
        });

        return c;
      });

      campaignIds.push(campaign.id);
      campaignLeaders.set(campaign.id, leaderId);
      campaignStances.set(campaign.id, tmpl.stanceType);
    } catch (err) {
      // If leader has insufficient balance, skip
      console.log(`   ⚠ Skipped campaign "${tmpl.title}": ${(err as Error).message?.slice(0, 60)}`);
      // Push a placeholder to keep indices aligned
      campaignIds.push('SKIPPED');
    }

    if ((i + 1) % 100 === 0) console.log(`   ✓ ${i + 1}/500 campaigns created`);
  }

  // Filter out skipped campaigns
  const validCampaignIds = campaignIds.filter(id => id !== 'SKIPPED');
  console.log(`   ✅ ${validCampaignIds.length} campaigns created.\n`);

  // ══════════════════════════════════════════════════════════════════════════
  // PHASE B2: Add members to campaigns
  // ══════════════════════════════════════════════════════════════════════════
  console.log('👥 Phase B2: Adding members to campaigns...');
  const membershipMap: Map<string, Set<string>> = new Map();
  for (const cid of validCampaignIds) {
    membershipMap.set(cid, new Set([campaignLeaders.get(cid)!]));
  }

  // Distribute 1000 users across campaigns — each user joins 1-5 campaigns
  const userCampaignCount = new Map<string, number>();
  for (const uid of createdUserIds) {
    userCampaignCount.set(uid, 0);
  }

  for (let cIdx = 0; cIdx < validCampaignIds.length; cIdx++) {
    const cid = validCampaignIds[cIdx]!;
    const stance = campaignStances.get(cid) ?? 'SUPPORT';
    const multiplier = INITIAL_MULTIPLIER[stance] ?? 1.0;

    // Determine member count based on campaign position (first campaigns get more members)
    // Creates a power-law distribution: some campaigns with many members, most with fewer
    let numMembers: number;
    if (cIdx < 10) numMembers = 30 + Math.floor(Math.random() * 40); // 30-70 members (top campaigns)
    else if (cIdx < 50) numMembers = 10 + Math.floor(Math.random() * 20); // 10-30
    else if (cIdx < 150) numMembers = 5 + Math.floor(Math.random() * 10); // 5-15
    else numMembers = 2 + Math.floor(Math.random() * 6); // 2-8

    // Pick candidates — prefer users who aren't in too many campaigns
    const candidates = createdUserIds
      .filter(uid => !membershipMap.get(cid)!.has(uid) && (userCampaignCount.get(uid) ?? 0) < 5)
      .sort(() => Math.random() - 0.5)
      .slice(0, numMembers);

    for (const memberId of candidates) {
      const stakeAmount = new Prisma.Decimal((1 + Math.floor(Math.random() * 5)).toFixed(6));

      // For REFORM: set varied joinedAt for time-based multiplier testing
      const joinedAt = stance === 'REFORM'
        ? new Date(Date.now() - Math.floor(Math.random() * 180) * 86400000)
        : new Date();

      try {
        await prisma.$transaction(async (tx) => {
          await tx.userWac.update({
            where: { userId: memberId },
            data: {
              wacBalance: { decrement: stakeAmount },
              balanceUpdatedAt: new Date(),
            },
          });

          await (tx as any).campaignMember.create({
            data: {
              campaignId: cid,
              userId: memberId,
              stakedWac: stakeAmount,
              multiplier,
              joinedAt,
            },
          });

          await tx.campaign.update({
            where: { id: cid },
            data: {
              totalWacStaked: { increment: stakeAmount },
              ...(stance === 'EMERGENCY' ? { emergencyWacPool: { increment: stakeAmount } } : {}),
            },
          });

          await recordChainedTransaction(tx, {
            userId: memberId,
            amount: stakeAmount,
            type: 'WAC_CAMPAIGN_STAKE' as any,
            note: `Joined [${stance}] campaign — staked ${stakeAmount} WAC`,
            campaignId: cid,
          });
        });

        membershipMap.get(cid)!.add(memberId);
        userCampaignCount.set(memberId, (userCampaignCount.get(memberId) ?? 0) + 1);
      } catch {
        // Skip if balance or unique constraint
      }
    }

    if ((cIdx + 1) % 100 === 0) console.log(`   ✓ Members added to ${cIdx + 1}/${validCampaignIds.length} campaigns`);
  }

  // Log member distribution
  const stanceCounts = { SUPPORT: 0, REFORM: 0, PROTEST: 0, EMERGENCY: 0 };
  const stanceMembers = { SUPPORT: 0, REFORM: 0, PROTEST: 0, EMERGENCY: 0 };
  for (const cid of validCampaignIds) {
    const stance = campaignStances.get(cid) as keyof typeof stanceCounts;
    if (stance) {
      stanceCounts[stance]++;
      stanceMembers[stance] += membershipMap.get(cid)?.size ?? 0;
    }
  }
  console.log(`   📊 SUPPORT: ${stanceCounts.SUPPORT} campaigns, ${stanceMembers.SUPPORT} memberships`);
  console.log(`   📊 REFORM:  ${stanceCounts.REFORM} campaigns, ${stanceMembers.REFORM} memberships`);
  console.log(`   📊 PROTEST: ${stanceCounts.PROTEST} campaigns, ${stanceMembers.PROTEST} memberships`);
  console.log(`   📊 EMERGENCY: ${stanceCounts.EMERGENCY} campaigns, ${stanceMembers.EMERGENCY} memberships`);
  console.log('');

  // ══════════════════════════════════════════════════════════════════════════
  // PHASE C: Social Graph (follows)
  // ══════════════════════════════════════════════════════════════════════════
  console.log('🤝 Phase C: Building social graph...');
  let followCount = 0;

  for (let i = 0; i < createdUserIds.length; i++) {
    const userId = createdUserIds[i]!;
    const numFollows = 5 + Math.floor(Math.random() * 15);
    const shuffled = [...createdUserIds].filter(id => id !== userId).sort(() => Math.random() - 0.5);
    const toFollow = shuffled.slice(0, numFollows);

    const followData = toFollow.map(targetId => ({
      followerId: userId,
      followingId: targetId,
      status: 'APPROVED' as const,
    }));

    try {
      const result = await prisma.follow.createMany({
        data: followData,
        skipDuplicates: true,
      });
      followCount += result.count;
    } catch {
      // Skip duplicates
    }

    if ((i + 1) % 200 === 0) console.log(`   ✓ Follows created for ${i + 1}/1000 users`);
  }

  // Update follower counts on icons
  const followerCounts = await prisma.follow.groupBy({
    by: ['followingId'],
    where: { status: 'APPROVED' },
    _count: true,
  });
  for (const fc of followerCounts) {
    await prisma.icon.updateMany({
      where: { userId: fc.followingId },
      data: { followerCount: fc._count },
    });
  }
  console.log(`   ✅ ${followCount} follow relationships created.\n`);

  // ══════════════════════════════════════════════════════════════════════════
  // PHASE D: Economy (exits → RAC minting → protest pool deposits)
  // ══════════════════════════════════════════════════════════════════════════
  console.log('💰 Phase D: Economy activation...');

  // Pick ~50 bots to exit SUPPORT campaigns (generating RAC)
  const exitCandidates: { userId: string; campaignId: string; stakedWac: Prisma.Decimal; stance: string }[] = [];
  for (const cid of validCampaignIds) {
    const stance = campaignStances.get(cid)!;
    if (stance === 'EMERGENCY') continue; // No exits from emergency
    const leaderId = campaignLeaders.get(cid)!;
    const nonLeaders = [...(membershipMap.get(cid) ?? [])].filter(id => id !== leaderId);
    if (nonLeaders.length > 3 && Math.random() < 0.3) {
      const exitUser = nonLeaders[Math.floor(Math.random() * nonLeaders.length)]!;
      const member = await (prisma as any).campaignMember.findUnique({
        where: { campaignId_userId: { campaignId: cid, userId: exitUser } },
      });
      if (member) {
        exitCandidates.push({ userId: exitUser, campaignId: cid, stakedWac: member.stakedWac, stance });
      }
    }
  }

  let exitCount = 0;
  for (const exit of exitCandidates.slice(0, 50)) {
    const stakedWac = exit.stakedWac;
    const penaltyRate = exit.stance === 'REFORM' ? 0.50 : 0.30; // REFORM 50%, others 30%
    const penalty = stakedWac.mul(penaltyRate.toString()).toDecimalPlaces(6);
    const returnAmount = stakedWac.sub(penalty).toDecimalPlaces(6);
    const burnAmount = penalty.mul('0.50').toDecimalPlaces(6);
    const devAmount = penalty.sub(burnAmount);
    const racReward = BigInt(penalty.mul('2').floor().toFixed(0));

    try {
      await prisma.$transaction(async (tx) => {
        await (tx as any).campaignMember.delete({
          where: { campaignId_userId: { campaignId: exit.campaignId, userId: exit.userId } },
        });

        await tx.campaign.update({
          where: { id: exit.campaignId },
          data: { totalWacStaked: { decrement: stakedWac } },
        });

        await tx.userWac.update({
          where: { userId: exit.userId },
          data: { wacBalance: { increment: returnAmount }, balanceUpdatedAt: new Date() },
        });

        await tx.treasury.upsert({
          where: { id: 'singleton' },
          update: { burnedTotal: { increment: burnAmount }, devBalance: { increment: devAmount } },
          create: { id: 'singleton', burnedTotal: burnAmount, devBalance: devAmount },
        });

        if (racReward > 0n) {
          await tx.userRac.upsert({
            where: { userId: exit.userId },
            update: { racBalance: { increment: racReward } },
            create: { userId: exit.userId, racBalance: racReward },
          });
        }

        await recordChainedTransaction(tx, {
          userId: exit.userId, amount: returnAmount,
          type: 'WAC_CAMPAIGN_RETURN' as any,
          note: `[${exit.stance}] exit — ${Math.round((1 - penaltyRate) * 100)}% returned`, campaignId: exit.campaignId,
        });
        await recordChainedTransaction(tx, {
          userId: exit.userId, amount: burnAmount,
          type: 'WAC_BURN' as any,
          note: `[${exit.stance}] exit — burned`, campaignId: exit.campaignId,
        });
        await recordChainedTransaction(tx, {
          userId: exit.userId, amount: racReward.toString(),
          type: 'RAC_MINTED' as any,
          note: `[${exit.stance}] exit — ${racReward} RAC minted`, campaignId: exit.campaignId,
        });

        await (tx as any).campaignHistory.create({
          data: {
            userId: exit.userId,
            campaignId: exit.campaignId,
            joinedAt: new Date(Date.now() - 86400000 * (3 + Math.floor(Math.random() * 30))),
            totalEarned: returnAmount,
          },
        });
      });

      membershipMap.get(exit.campaignId)!.delete(exit.userId);
      exitCount++;
    } catch {
      // Skip on error
    }
  }
  console.log(`   ✓ ${exitCount} campaign exits completed.`);

  // RAC Protest Pool deposits
  const racHolders = await prisma.userRac.findMany({
    where: { racBalance: { gt: 0 } },
    select: { userId: true, racBalance: true },
  });

  let poolCount = 0;
  for (const holder of racHolders) {
    const userCampaigns = new Set<string>();
    for (const [cid, members] of membershipMap.entries()) {
      if (members.has(holder.userId)) userCampaigns.add(cid);
    }
    const protestable = validCampaignIds.filter(cid => !userCampaigns.has(cid) && campaignStances.get(cid) !== 'EMERGENCY');
    if (protestable.length === 0) continue;

    const targetCampaignId = protestable[Math.floor(Math.random() * protestable.length)]!;
    const depositAmount = BigInt(Math.min(Number(holder.racBalance), 1 + Math.floor(Math.random() * 3)));

    try {
      await prisma.$transaction(async (tx) => {
        let pool = await tx.racPool.findUnique({ where: { targetCampaignId } });
        if (!pool) {
          pool = await tx.racPool.create({
            data: {
              targetCampaignId,
              representativeId: holder.userId,
              totalBalance: depositAmount,
              participantCount: 1,
            },
          });
        } else {
          await tx.racPool.update({
            where: { id: pool.id },
            data: { totalBalance: { increment: depositAmount }, participantCount: { increment: 1 } },
          });
        }

        await tx.racPoolParticipant.create({
          data: { poolId: pool.id, userId: holder.userId, contribution: depositAmount },
        });

        await tx.userRac.update({
          where: { userId: holder.userId },
          data: { racBalance: { decrement: depositAmount } },
        });

        await recordChainedTransaction(tx, {
          userId: holder.userId, amount: depositAmount.toString(),
          type: 'RAC_POOL_DEPOSIT' as any,
          note: `Deposited ${depositAmount} RAC into protest pool`, campaignId: targetCampaignId,
        });
      });
      poolCount++;
    } catch {
      // Skip unique constraint errors
    }
  }
  console.log(`   ✓ ${poolCount} RAC protest pool deposits.\n`);

  // ══════════════════════════════════════════════════════════════════════════
  // PHASE E: Polls & Votes
  // ══════════════════════════════════════════════════════════════════════════
  console.log('🗳 Phase E: Creating polls and votes...');
  let pollCount = 0;
  let voteCount = 0;

  for (let cIdx = 0; cIdx < validCampaignIds.length; cIdx++) {
    const cid = validCampaignIds[cIdx]!;
    const members = [...(membershipMap.get(cid) || [])];

    if (Math.random() < 0.5 && members.length >= 3) {
      const tmpl = POLL_TEMPLATES[cIdx % POLL_TEMPLATES.length]!;
      const endsAt = new Date(Date.now() + 86400000 * (1 + Math.floor(Math.random() * 5)));

      const poll = await (prisma as any).campaignPoll.create({
        data: {
          campaignId: cid,
          title: tmpl.title,
          description: `Poll for campaign #${cIdx + 1}`,
          endsAt,
          options: { create: tmpl.options.map(text => ({ text })) },
        },
        include: { options: true },
      });
      pollCount++;

      for (const memberId of members) {
        if (Math.random() < 0.2) continue; // 20% skip
        const randomOption = poll.options[Math.floor(Math.random() * poll.options.length)];

        const membership = await (prisma as any).campaignMember.findUnique({
          where: { campaignId_userId: { campaignId: cid, userId: memberId } },
        });
        if (!membership) continue;

        try {
          await prisma.pollVote.create({
            data: {
              pollId: poll.id,
              optionId: randomOption.id,
              voterId: memberId,
              wacWeight: membership.stakedWac,
            },
          });
          voteCount++;
        } catch {
          // Skip duplicate votes
        }
      }
    }
  }
  console.log(`   ✅ ${pollCount} polls, ${voteCount} votes.\n`);

  // ══════════════════════════════════════════════════════════════════════════
  // PHASE F: Direct Messages
  // ══════════════════════════════════════════════════════════════════════════
  console.log('💬 Phase F: Creating direct messages...');
  const messages: { senderId: string; receiverId: string; content: string }[] = [];

  for (let i = 0; i < 300; i++) {
    const senderIdx = Math.floor(Math.random() * createdUserIds.length);
    let receiverIdx = Math.floor(Math.random() * createdUserIds.length);
    while (receiverIdx === senderIdx) {
      receiverIdx = Math.floor(Math.random() * createdUserIds.length);
    }
    messages.push({
      senderId: createdUserIds[senderIdx]!,
      receiverId: createdUserIds[receiverIdx]!,
      content: DM_TEMPLATES[i % DM_TEMPLATES.length]!,
    });
  }

  await prisma.directMessage.createMany({ data: messages });
  console.log(`   ✅ ${messages.length} direct messages created.\n`);

  // ══════════════════════════════════════════════════════════════════════════
  // DONE
  // ══════════════════════════════════════════════════════════════════════════
  console.log('════════════════════════════════════════════');
  console.log('🎉 Bot seeding v7 complete!');
  console.log(`   👤 Users:       1000`);
  console.log(`   🏴 Campaigns:   ${validCampaignIds.length}`);
  console.log(`      SUPPORT:     ${stanceCounts.SUPPORT}`);
  console.log(`      REFORM:      ${stanceCounts.REFORM}`);
  console.log(`      PROTEST:     ${stanceCounts.PROTEST}`);
  console.log(`      EMERGENCY:   ${stanceCounts.EMERGENCY}`);
  console.log(`   🤝 Follows:     ${followCount}`);
  console.log(`   🚪 Exits:       ${exitCount}`);
  console.log(`   ⚔ RAC Pools:   ${poolCount}`);
  console.log(`   🗳 Polls:       ${pollCount}`);
  console.log(`   ✉ Messages:    ${messages.length}`);
  console.log('════════════════════════════════════════════\n');
}

// ─── Entry Point ─────────────────────────────────────────────────────────────
seedBots()
  .catch(err => {
    console.error('❌ Seed failed:', err);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
