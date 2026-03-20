// @ts-nocheck
/**
 * seed_bots.ts — 300 Bot User Seeder
 *
 * Creates 300 realistic bot users with American names, campaigns, social graph,
 * WAC/RAC economy activity, polls, votes, and direct messages.
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

// Convert lng/lat → grid coordinates
function lngToGridX(lng: number): number {
  return (lng + 180) / 360 * GRID_WIDTH;
}
function latToGridY(lat: number): number {
  return (90 - lat) / 180 * GRID_HEIGHT;
}

// ─── US Cities with approximate lat/lng ──────────────────────────────────────
const US_CITIES = [
  { city: 'New York', x: -74.006, y: 40.7128 },
  { city: 'Los Angeles', x: -118.2437, y: 34.0522 },
  { city: 'Chicago', x: -87.6298, y: 41.8781 },
  { city: 'Houston', x: -95.3698, y: 29.7604 },
  { city: 'Phoenix', x: -112.074, y: 33.4484 },
  { city: 'Philadelphia', x: -75.1652, y: 39.9526 },
  { city: 'San Antonio', x: -98.4936, y: 29.4241 },
  { city: 'San Diego', x: -117.1611, y: 32.7157 },
  { city: 'Dallas', x: -96.797, y: 32.7767 },
  { city: 'San Jose', x: -121.8863, y: 37.3382 },
  { city: 'Austin', x: -97.7431, y: 30.2672 },
  { city: 'Jacksonville', x: -81.6557, y: 30.3322 },
  { city: 'San Francisco', x: -122.4194, y: 37.7749 },
  { city: 'Columbus', x: -82.9988, y: 39.9612 },
  { city: 'Charlotte', x: -80.8431, y: 35.2271 },
  { city: 'Indianapolis', x: -86.1581, y: 39.7684 },
  { city: 'Seattle', x: -122.3321, y: 47.6062 },
  { city: 'Denver', x: -104.9903, y: 39.7392 },
  { city: 'Washington DC', x: -77.0369, y: 38.9072 },
  { city: 'Nashville', x: -86.7816, y: 36.1627 },
  { city: 'Portland', x: -122.6765, y: 45.5152 },
  { city: 'Las Vegas', x: -115.1398, y: 36.1699 },
  { city: 'Milwaukee', x: -87.9065, y: 43.0389 },
  { city: 'Memphis', x: -90.049, y: 35.1495 },
  { city: 'Baltimore', x: -76.6122, y: 39.2904 },
  { city: 'Boston', x: -71.0589, y: 42.3601 },
  { city: 'Miami', x: -80.1918, y: 25.7617 },
  { city: 'Atlanta', x: -84.388, y: 33.749 },
  { city: 'Detroit', x: -83.0458, y: 42.3314 },
  { city: 'Minneapolis', x: -93.265, y: 44.9778 },
  { city: 'Honolulu', x: -157.8583, y: 21.3069 },
  { city: 'Salt Lake City', x: -111.891, y: 40.7608 },
];

// ─── Icon Colors ─────────────────────────────────────────────────────────────
const COLORS = [
  '#2C3E50', '#E74C3C', '#3498DB', '#2ECC71', '#F39C12', '#9B59B6', '#1ABC9C',
  '#E67E22', '#34495E', '#16A085', '#C0392B', '#2980B9', '#27AE60', '#D35400',
  '#8E44AD', '#F1C40F', '#7F8C8D', '#00BCD4', '#FF5722', '#4CAF50', '#FF9800',
  '#795548', '#607D8B', '#E91E63', '#009688', '#673AB7', '#CDDC39', '#FF4081',
  '#00E676', '#AA00FF',
];

// ─── Bot Names & Profiles (300) ──────────────────────────────────────────────

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
  // 300 real American names across diverse backgrounds
  const names = [
    // Environmental activists (50)
    'James Wilson', 'Maria Garcia', 'David Chen', 'Ashley Johnson', 'Marcus Brown',
    'Sarah Kim', 'Robert Taylor', 'Jessica Martinez', 'Michael Davis', 'Emily Anderson',
    'Christopher Lee', 'Amanda Thomas', 'Daniel Jackson', 'Samantha White', 'Matthew Harris',
    'Lauren Martin', 'Andrew Thompson', 'Rachel Moore', 'Joshua Clark', 'Megan Lewis',
    'Brandon Robinson', 'Stephanie Walker', 'Kevin Young', 'Nicole Allen', 'Justin King',
    'Amber Wright', 'Ryan Scott', 'Kayla Green', 'Tyler Baker', 'Brittany Adams',
    'Nathan Nelson', 'Danielle Hill', 'Cody Campbell', 'Chelsea Mitchell', 'Kyle Roberts',
    'Heather Carter', 'Patrick Phillips', 'Tiffany Evans', 'Sean Turner', 'Christina Torres',
    'Derek Parker', 'Melissa Collins', 'Dustin Edwards', 'Monica Stewart', 'Trevor Sanchez',
    'Diana Morris', 'Chad Rogers', 'Courtney Reed', 'Brett Cook', 'Lindsey Morgan',
    // Tech enthusiasts (50)
    'Alex Rivera', 'Priya Patel', 'Jake Morrison', 'Suki Nakamura', 'Omar Hassan',
    'Emma Thompson', 'Raj Krishnan', 'Sophie Chen', 'Liam OBrien', 'Aisha Washington',
    'Ben Goldstein', 'Maya Rodriguez', 'Ethan Park', 'Zara Ahmed', 'Noah Williams',
    'Chloe Bennett', 'Aaron Murphy', 'Grace Liu', 'Dylan Cooper', 'Lily Chang',
    'Connor Bailey', 'Ava Foster', 'Lucas Nguyen', 'Hailey Reed', 'Ian Hoffman',
    'Olivia Santos', 'Adrian Reyes', 'Natalie Cruz', 'Vincent Wu', 'Isabel Flores',
    'Derek Zhang', 'Jasmine Adams', 'Maxwell Grant', 'Kira Yamamoto', 'Philip Frost',
    'Tanya Volkov', 'Oscar Ramirez', 'Fiona Shaw', 'Miles Tucker', 'Leah Romero',
    'Harrison Price', 'Naomi Hart', 'Felix Ortega', 'Ruby Spencer', 'Caleb Tran',
    'Sierra Wells', 'Dominic Vargas', 'Audrey Knight', 'Gavin Roy', 'Elise Pearson',
    // Sports fans (40)
    'Tony Jackson', 'Serena Brooks', 'Marcus Williams', 'Tamika Davis', 'Jake Rodriguez',
    'Brittany Howard', 'DeAndre Jones', 'Mia Sullivan', 'Carlos Mendez', 'Jordan Bell',
    'Tyrone Mitchell', 'Kayla Stevens', 'Andre Washington', 'Crystal Hayes', 'Darnell Cooper',
    'Tessa Richardson', 'Brandon Hawkins', 'Destiny Simmons', 'Jamal Foster', 'Brianna Russell',
    'Rashad Griffin', 'Alicia Barnes', 'Terrence Long', 'Jasmin Perry', 'Cedric Patterson',
    'Monica Diaz', 'Devin Coleman', 'Shanice Jenkins', 'Xavier Powell', 'Kiara Henderson',
    'Dante Alexander', 'Aaliyah Butler', 'Lamar Bryant', 'Ebony Washington', 'Marquis Ross',
    'Tiana James', 'Kendrick Watson', 'Monique Brooks', 'Dwayne Curtis', 'Leticia Gonzalez',
    // Arts & Culture (40)
    'Zoe Hartwell', 'Sebastian Blake', 'Luna Castillo', 'Theo Ashford', 'Aurora Vega',
    'Julian Mercer', 'Ivy Thornton', 'Dorian Hayes', 'Celeste Rivera', 'August Sterling',
    'Freya Delacroix', 'Leonardo Giordano', 'Violet Sinclair', 'Atticus Monroe', 'Dahlia Quinn',
    'Raphael Costa', 'Iris Chandler', 'Silas Whitmore', 'Scarlett Fontaine', 'Hugo Brennan',
    'Aria Montenegro', 'Jasper Caldwell', 'Willow Prescott', 'Felix Valentine', 'Lydia Beaumont',
    'Orion Drake', 'Penelope Archer', 'Roman Blackwood', 'Elara Jennings', 'Beckett Harlow',
    'Juniper Frost', 'Ezra McCormick', 'Ophelia Nightingale', 'Caspian Rhodes', 'Seraphina Bell',
    'Tobias Kane', 'Clementine Hart', 'Arlo Sutherland', 'Rosalie Dunn', 'Dashiell Gray',
    // Community organizers (40)
    'Pastor Earl Williams', 'Rosa Hernandez', 'Chief Mike Redhawk', 'Dorothy Franklin',
    'Rev. James Stone', 'Consuelo Padilla', 'Walter Jenkins', 'Betty Washington',
    'Frank Moretti', 'Grace Okonkwo', 'Harold Swenson', 'Maria Rosario',
    'George Tanaka', 'Helen Kowalski', 'Arthur Chambers', 'Carla Jimenez',
    'Roy Blackhorse', 'Gladys Petersen', 'Wayne Holloway', 'Dolores Santiago',
    'Eugene Yamashita', 'Bernice Goldman', 'Vernon Littlefeather', 'Alma Cervantes',
    'Clifford Johansson', 'Ruth Abubakar', 'Howard Zimmerman', 'Loretta Gutierrez',
    'Stanley Okamura', 'Mabel Christensen', 'Leonard Tsosie', 'Estelle Beauchamp',
    'Norman Fujimoto', 'Iris Delgado', 'Raymond Kingfisher', 'Carmen Villanueva',
    'Ernest Magnusson', 'Juanita Bautista', 'Alfred Whitehawk', 'Lucille Montoya',
    // Political activists (30)
    'Senator-hopeful Tom Barrett', 'Activist Maya Freeman', 'Journalist Kai Henderson',
    'Blogger Patricia Okafor', 'Organizer Luis Torres', 'Advocate Diana Wolfe',
    'Pundit Charles Whitfield', 'Campaigner Nina Volkov', 'Strategist Derek Moss',
    'Analyst Priscilla Duarte', 'Lobbyist Warren Kessler', 'Reformer Amara Diallo',
    'Commentator Travis Pope', 'Canvasser Yuki Tanaka', 'Researcher Gil Shapiro',
    'Speaker Fatima El-Amin', 'Delegate Hector Ayala', 'Watchdog Rebecca Nash',
    'Pollster Kevin Dougherty', 'Activist Sade Johnson', 'Fundraiser Mitchell Crane',
    'Educator Raven Sinclair', 'Volunteer Javier Gutierrez', 'Coordinator Leah Pham',
    'Intern Marcus Cho', 'Advocate Tamara Willis', 'Director Samuel Pierce',
    'Liaison Chelsea Torres', 'Advisor Franklin Wu', 'Captain Rosa Medina',
    // Entrepreneurs (25)
    'CEO Blake Chambers', 'Founder Ananya Sharma', 'Startup Wiz Chad Brennan',
    'Innovator Mei Lin', 'Investor Diego Navarro', 'Disruptor Kennedy Shaw',
    'Maker Yusuf Ibrahim', 'Builder Samantha Pike', 'Hustler Trent Calloway',
    'Visionary Aiko Watanabe', 'Mogul Preston Drake', 'Pioneer Zuri Okafor',
    'Strategist Lena Richter', 'Founder Kareem Abdul', 'Hacker Quinn Donovan',
    'Creator Paloma Reyes', 'Inventor Boris Petrov', 'Accelerator Jade Nakamura',
    'Scaler Rodrigo Mendes', 'Architect Simone Bassett', 'Bootstrapper Tucker Hayes',
    'Operator Nadia Volkov', 'Growth Ace Damien Frost', 'Builder Asha Reddy',
    'Launcher Giovanni Bianchi',
    // Students & Youth (25)
    'Freshman Tyler Kim', 'Sophomore Aaliyah Green', 'Junior Marcus Cho',
    'Senior Emma Sullivan', 'Grad Student Ravi Kapoor', 'Intern Zoe Martinez',
    'Freshman Jake Okonkwo', 'Transfer Lily Tran', 'TA Omar Sayed',
    'Club Pres Aria Washington', 'Activist Kai Rivera', 'Editor Naomi Park',
    'Tutor Devon Chang', 'Athlete Sierra Johnson', 'Artist Elijah Brooks',
    'Debater Priya Singh', 'Coder Leo Yamamoto', 'Volunteer Maya Patel',
    'President Dante Williams', 'Secretary Hana Kim', 'Treasurer Finn OConnor',
    'Captain Jade Thompson', 'Rep Sofia Hernandez', 'Scholar Amir Hassan',
    'Mentor Brooklyn Davis',
  ];

  const slogans: Record<string, string[]> = {
    env: [
      'Planet Earth First', 'Go Green or Go Home', 'Save Our Oceans', 'Trees Are Life',
      'Eco Warrior', 'Zero Waste Advocate', 'Clean Air Now', 'Solar Powered Soul',
      'Earth Defender', 'Nature Over Profit', 'Protect Wildlife', 'Sustainable Future',
      'Green Revolution', 'Ocean Guardian', 'Climate Action Now', 'Plant More Trees',
      'Reduce Reuse Recycle', 'Carbon Neutral Life', 'Earth First Always', 'Eco Conscious',
      'Wild At Heart', 'Seas The Day', 'Nature Is Home', 'Green Is The New Gold',
      'One Earth One Chance', 'Water Is Life', 'Breathe Clean Air', 'Save The Bees',
      'Rainforest Protector', 'Plastic Free Future', 'Compost Everything', 'Wind Power Fan',
      'Electric Dreams', 'Organic Living', 'Rewild The Planet', 'Wetland Warrior',
      'Clean Energy Now', 'Coral Reef Saver', 'Desert Bloom', 'Arctic Guardian',
      'Permaculture Pro', 'Seed Saver', 'Farm To Table', 'Soil Health First',
      'Green Thumb Life', 'Butterfly Effect', 'River Keeper', 'Sky Watcher',
      'Mountain Spirit', 'Forest Bathing',
    ],
    tech: [
      'Code Is Poetry', 'Debug The World', 'Open Source Hero', 'AI For Good',
      'Hack The Planet', 'Bits And Bytes', 'Cloud Native', 'Full Stack Dreamer',
      'Git Commit Life', 'Always Be Shipping', 'Data Driven', 'Privacy Matters',
      'Crypto Curious', 'Build Break Learn', 'Ship It Fast', 'API First',
      'Machine Learning', 'Blockchain Builder', 'DevOps Culture', 'UI/UX Obsessed',
      'Linux Forever', 'Python Power', 'Rust Evangelist', 'TypeScript Lover',
      'Web3 Pioneer', 'Quantum Ready', 'IoT Explorer', 'Cybersecurity Pro',
      'Agile Mindset', 'Test Driven Dev', 'Clean Code Guru', 'Docker Captain',
      'Kubernetes Master', 'React Native Pro', 'Flutter Developer', 'Swift Coder',
      'Go Gopher', 'Neural Networks', 'Edge Computing', 'Serverless Fan',
      'GraphQL Wizard', 'NoSQL Pioneer', 'Microservices', 'Zero Trust Arch',
      'Digital Nomad', 'Remote First', 'Pair Programming', 'Code Review King',
      'Tech For All', 'Innovation Lab',
    ],
    sports: [
      'Ball Is Life', 'Never Stop Running', 'Champion Mindset', 'Game Day Ready',
      'Sports Unite Us', 'Train Hard Win Big', 'Heart Of A Champion', 'Play Every Day',
      'Victory Or Nothing', 'Born To Compete', 'Team Player Always', 'Grind And Shine',
      'Sweat Equity', 'No Pain No Gain', 'Rise And Grind', 'Beast Mode On',
      'Speed Demon', 'Iron Will', 'Court King', 'Diamond Dreams',
      'Touchdown Bound', 'Slam Dunk Life', 'Hat Trick Hero', 'Goal Crusher',
      'Marathon Runner', 'Gym Warrior', 'Fight Club Member', 'Surf The Wave',
      'Ski Bum Life', 'Mountain Climber', 'Ice Cold Player', 'Track Star',
      'Swimming Champion', 'Boxing Spirit', 'Wrestling Heart', 'Tennis Ace',
      'Golf Pro Life', 'Cycling Spirit', 'Skate Or Die', 'MMA Fighter',
    ],
    arts: [
      'Art Speaks Louder', 'Create Every Day', 'Paint The World', 'Music Is Life',
      'Dance Like Nobody', 'Stage Is My Home', 'Write Your Story', 'Sculpt Reality',
      'Film Everything', 'Poetry In Motion', 'Color My World', 'Rhythm And Blues',
      'Canvas Dreams', 'Jazz Soul Living', 'Photography Love', 'Street Art King',
      'Graffiti Culture', 'Indie Film Maker', 'Theater Geek', 'Opera Lover',
      'Classical Heart', 'Rock And Roll', 'Hip Hop Culture', 'EDM Festival',
      'Sketch Every Day', 'Watercolor Vibes', 'Digital Art Pro', 'Ceramic Artist',
      'Glass Blowing Art', 'Textile Designer', 'Jewel Crafter', 'Print Maker',
      'Calligraphy Fan', 'Origami Master', 'Puppet Theater', 'Mime Art',
      'Stand Up Comedy', 'Spoken Word', 'Beat Boxing', 'DJing Life',
    ],
    community: [
      'Community Strong', 'Together We Rise', 'Neighbors First', 'Local Hero',
      'Build Community', 'Serve Others First', 'United We Stand', 'Help Your Neighbor',
      'Grassroots Power', 'People Over Profit', 'Community Garden', 'Food For All',
      'Shelter Everyone', 'Education First', 'Teach And Learn', 'Mentor The Youth',
      'Elder Wisdom', 'Faith In Action', 'Hope And Service', 'Volunteer Spirit',
      'Clean Streets Now', 'Safe Neighborhoods', 'Public Health', 'Mental Health Ally',
      'Refugee Welcome', 'Immigrant Rights', 'Disability Ally', 'Veterans Support',
      'Homeless Outreach', 'Literacy Campaign', 'After School Care', 'Summer Camp',
      'Block Party King', 'Town Hall Regular', 'PTA President', 'Scout Leader',
      'Church Volunteer', 'Mosque Helper', 'Temple Servant', 'Community Center',
    ],
    politics: [
      'Vote Every Time', 'Democracy Matters', 'Civic Duty First', 'Transparency Now',
      'Hold Power Accountable', 'Reform Not Revolt', 'Policy Wonk', 'Data Over Drama',
      'Term Limits Now', 'Campaign Finance Fix', 'Free Press Defender', 'Bill Of Rights',
      'Constitution Lover', 'Local Politics', 'State Rights', 'Federal Reform',
      'Bipartisan Bridge', 'Independent Voice', 'Moderate Middle', 'Progressive Push',
      'Liberty And Justice', 'Equal Rights Now', 'Tax Reform Needed', 'Budget Hawk',
      'Green New Dealer', 'Healthcare For All', 'Education Budget', 'Infrastructure Now',
      'Criminal Justice', 'Immigration Reform', 'Gun Safety Laws',
    ],
    entrepreneur: [
      'Ship Or Die', 'Move Fast Build', 'Startup Life', 'Founder Mode On',
      'Build Something Great', 'Disrupt Everything', 'Scale Or Fail', 'Growth Hacker',
      'Revenue First', 'Product Market Fit', 'Lean Startup', 'Bootstrap King',
      'Venture Ready', 'Pitch Perfect', 'Market Leader', 'Innovation Engine',
      'Side Hustle King', 'Serial Founder', 'Exit Strategy', 'Unicorn Hunter',
      'Angel Investor', 'Seed Stage', 'Series A Ready', 'IPO Dreamer',
      'Profit Machine',
    ],
    student: [
      'Study Hard Play Hard', 'Future Leader', 'Campus Life', 'Degree Loading',
      'Student Debt Fighter', 'Knowledge Seeker', 'Class Of 2027', 'Dean List Goals',
      'Library Warrior', 'All Nighter Pro', 'Scholarship Kid', 'Exchange Student',
      'Research Assistant', 'Lab Rat Life', 'Thesis Writing', 'Internship Hustle',
      'Greek Life Member', 'Club President', 'Dorm Room Dreams', 'Cafeteria Regular',
      'Finals Survivor', 'GPA Warrior', 'College Bound', 'Alma Mater Pride',
      'Graduation Day',
    ],
  };

  const categories = ['env', 'tech', 'sports', 'arts', 'community', 'politics', 'entrepreneur', 'student'];
  const categorySizes = [50, 50, 40, 40, 40, 30, 25, 25];

  const bots: BotProfile[] = [];
  let nameIdx = 0;

  for (let catIdx = 0; catIdx < categories.length; catIdx++) {
    const cat = categories[catIdx]!;
    const size = categorySizes[catIdx]!;
    const catSlogans = slogans[cat]!;

    for (let i = 0; i < size; i++) {
      bots.push({
        name: names[nameIdx]!,
        slogan: catSlogans[i % catSlogans.length]!,
        category: cat,
        colorHex: COLORS[nameIdx % COLORS.length]!,
        shapeIndex: nameIdx % 5,
        exploreMode: nameIdx % 3, // 0=City, 1=Country, 2=World
        cityIdx: nameIdx % US_CITIES.length,
      });
      nameIdx++;
    }
  }

  return bots;
}

// ─── Campaign Templates ─────────────────────────────────────────────────────

interface CampaignTemplate {
  title: string;
  slogan: string;
  description: string;
  category: string;
  iconColor: string;
  speed: number;
  stakeAmount: number;
}

const CAMPAIGN_TEMPLATES: CampaignTemplate[] = [
  // Environmental (10)
  { title: 'Clean Ocean Initiative', slogan: 'Every Drop Counts', description: 'Working together to remove plastic from our oceans and protect marine life for future generations.', category: 'env', iconColor: '#1ABC9C', speed: 0.6, stakeAmount: 5 },
  { title: 'Solar Future Alliance', slogan: 'Power The Sun', description: 'Advocating for solar energy adoption in every American household by 2030.', category: 'env', iconColor: '#F39C12', speed: 0.7, stakeAmount: 8 },
  { title: 'Save The Bees Coalition', slogan: 'No Bees No Food', description: 'Protecting pollinator habitats and banning harmful pesticides across the nation.', category: 'env', iconColor: '#F1C40F', speed: 0.5, stakeAmount: 3 },
  { title: 'Rewild America', slogan: 'Nature Reclaims', description: 'Restoring 100 million acres of wild land to their natural state.', category: 'env', iconColor: '#27AE60', speed: 0.4, stakeAmount: 6 },
  { title: 'Zero Waste Movement', slogan: 'Trash Is Treasure', description: 'Building a circular economy where nothing goes to waste.', category: 'env', iconColor: '#2ECC71', speed: 0.5, stakeAmount: 4 },
  { title: 'Clean Air Now', slogan: 'Breathe Free', description: 'Fighting air pollution in the 50 most polluted US cities.', category: 'env', iconColor: '#3498DB', speed: 0.6, stakeAmount: 5 },
  { title: 'River Restoration Project', slogan: 'Let Rivers Run', description: 'Removing obsolete dams and restoring natural river ecosystems.', category: 'env', iconColor: '#2980B9', speed: 0.3, stakeAmount: 7 },
  { title: 'Urban Forest Campaign', slogan: 'City Trees Matter', description: 'Planting one million trees in urban areas to combat heat islands.', category: 'env', iconColor: '#16A085', speed: 0.5, stakeAmount: 4 },
  { title: 'Coral Reef Guardians', slogan: 'Protect The Reef', description: 'Monitoring and restoring coral reefs across Florida and Hawaii.', category: 'env', iconColor: '#E74C3C', speed: 0.4, stakeAmount: 6 },
  { title: 'Sustainable Farming Fund', slogan: 'Feed The Future', description: 'Supporting regenerative agriculture practices for American farmers.', category: 'env', iconColor: '#8E44AD', speed: 0.5, stakeAmount: 5 },
  // Tech (10)
  { title: 'AI Ethics Board', slogan: 'Responsible AI', description: 'Establishing ethical guidelines for artificial intelligence development and deployment.', category: 'tech', iconColor: '#9B59B6', speed: 0.8, stakeAmount: 7 },
  { title: 'Open Source Movement', slogan: 'Code For All', description: 'Promoting open source software and collaborative development.', category: 'tech', iconColor: '#2C3E50', speed: 0.7, stakeAmount: 5 },
  { title: 'Digital Privacy Rights', slogan: 'Your Data Your Rights', description: 'Fighting for stronger data privacy laws and digital rights.', category: 'tech', iconColor: '#34495E', speed: 0.6, stakeAmount: 6 },
  { title: 'Code Education For All', slogan: 'Everyone Can Code', description: 'Bringing computer science education to every school in America.', category: 'tech', iconColor: '#3498DB', speed: 0.7, stakeAmount: 4 },
  { title: 'Cybersecurity Alliance', slogan: 'Secure The Net', description: 'Protecting critical infrastructure from cyber threats.', category: 'tech', iconColor: '#E74C3C', speed: 0.9, stakeAmount: 8 },
  { title: 'Web3 Builders Guild', slogan: 'Decentralize It', description: 'Building the decentralized web and empowering users.', category: 'tech', iconColor: '#F39C12', speed: 0.8, stakeAmount: 6 },
  { title: 'Green Tech Initiative', slogan: 'Tech Saves Earth', description: 'Using technology to solve environmental challenges.', category: 'tech', iconColor: '#2ECC71', speed: 0.6, stakeAmount: 5 },
  { title: 'Digital Inclusion Project', slogan: 'Bridge The Gap', description: 'Ensuring internet access and digital literacy for all Americans.', category: 'tech', iconColor: '#1ABC9C', speed: 0.5, stakeAmount: 4 },
  { title: 'Quantum Computing Club', slogan: 'Quantum Leap', description: 'Exploring and democratizing quantum computing technology.', category: 'tech', iconColor: '#8E44AD', speed: 0.9, stakeAmount: 7 },
  { title: 'Robot Ethics Forum', slogan: 'Bots With Morals', description: 'Discussing the ethical implications of robotics in society.', category: 'tech', iconColor: '#7F8C8D', speed: 0.6, stakeAmount: 3 },
  // Sports (8)
  { title: 'Youth Basketball League', slogan: 'Hoops For Hope', description: 'Providing free basketball programs for underprivileged youth.', category: 'sports', iconColor: '#E74C3C', speed: 0.9, stakeAmount: 5 },
  { title: 'Skatepark Alliance', slogan: 'Skate Free', description: 'Building free skateparks in communities across America.', category: 'sports', iconColor: '#F39C12', speed: 0.8, stakeAmount: 4 },
  { title: 'Community Soccer Fund', slogan: 'Goal Together', description: 'Making soccer accessible to every child regardless of income.', category: 'sports', iconColor: '#2ECC71', speed: 0.7, stakeAmount: 5 },
  { title: 'Swim For All', slogan: 'Every Kid Swims', description: 'Teaching water safety and swimming to underserved communities.', category: 'sports', iconColor: '#3498DB', speed: 0.6, stakeAmount: 3 },
  { title: 'Girls Sports Coalition', slogan: 'She Plays', description: 'Equal funding and opportunities for girls in sports.', category: 'sports', iconColor: '#E91E63', speed: 0.7, stakeAmount: 6 },
  { title: 'Veterans Athletics Program', slogan: 'Serve And Play', description: 'Sports rehabilitation and recreation for military veterans.', category: 'sports', iconColor: '#795548', speed: 0.5, stakeAmount: 4 },
  { title: 'Esports Academy', slogan: 'Game On', description: 'Building competitive gaming programs in schools.', category: 'sports', iconColor: '#9B59B6', speed: 0.8, stakeAmount: 5 },
  { title: 'Marathon For Charity', slogan: 'Run For Cause', description: 'Organizing charity marathons to fund community projects.', category: 'sports', iconColor: '#FF5722', speed: 0.9, stakeAmount: 3 },
  // Arts (8)
  { title: 'Street Art Collective', slogan: 'Walls Speak', description: 'Transforming blank walls into community art across US cities.', category: 'arts', iconColor: '#E91E63', speed: 0.5, stakeAmount: 4 },
  { title: 'Music Education Fund', slogan: 'Every Child Plays', description: 'Bringing music instruments and lessons to public schools.', category: 'arts', iconColor: '#9B59B6', speed: 0.4, stakeAmount: 5 },
  { title: 'Community Theater', slogan: 'Stage For All', description: 'Free community theater productions in parks and public spaces.', category: 'arts', iconColor: '#E74C3C', speed: 0.3, stakeAmount: 3 },
  { title: 'Poetry Slam Movement', slogan: 'Words Have Power', description: 'Organizing poetry slam events and spoken word performances.', category: 'arts', iconColor: '#673AB7', speed: 0.4, stakeAmount: 2 },
  { title: 'Film Festival Fund', slogan: 'Stories Matter', description: 'Supporting independent filmmakers and community film festivals.', category: 'arts', iconColor: '#FF9800', speed: 0.5, stakeAmount: 6 },
  { title: 'Dance Revolution', slogan: 'Move Together', description: 'Free dance classes and performances in community centers.', category: 'arts', iconColor: '#FF4081', speed: 0.7, stakeAmount: 3 },
  { title: 'Digital Arts Hub', slogan: 'Create Digital', description: 'Teaching digital art and design skills to aspiring artists.', category: 'arts', iconColor: '#00BCD4', speed: 0.6, stakeAmount: 4 },
  { title: 'Public Library Revival', slogan: 'Read And Grow', description: 'Modernizing public libraries and expanding community programs.', category: 'arts', iconColor: '#795548', speed: 0.3, stakeAmount: 5 },
  // Community (8)
  { title: 'Food Bank Network', slogan: 'No One Goes Hungry', description: 'Building a nationwide food bank network to end hunger.', category: 'community', iconColor: '#FF9800', speed: 0.4, stakeAmount: 5 },
  { title: 'Neighborhood Watch', slogan: 'Safe Streets', description: 'Community-driven safety patrols and crime prevention.', category: 'community', iconColor: '#607D8B', speed: 0.3, stakeAmount: 3 },
  { title: 'Homeless Shelter Project', slogan: 'Roof For Everyone', description: 'Building transitional housing and support services.', category: 'community', iconColor: '#795548', speed: 0.4, stakeAmount: 6 },
  { title: 'Senior Care Alliance', slogan: 'Honor Our Elders', description: 'Providing companionship and care for isolated seniors.', category: 'community', iconColor: '#9E9E9E', speed: 0.3, stakeAmount: 4 },
  { title: 'Youth Mentorship Program', slogan: 'Guide The Future', description: 'Connecting experienced mentors with at-risk youth.', category: 'community', iconColor: '#4CAF50', speed: 0.5, stakeAmount: 5 },
  { title: 'Community Health Center', slogan: 'Health For All', description: 'Affordable healthcare clinics in underserved neighborhoods.', category: 'community', iconColor: '#F44336', speed: 0.4, stakeAmount: 7 },
  { title: 'Immigrant Welcome Network', slogan: 'Welcome Home', description: 'Supporting new immigrants with language, jobs, and housing.', category: 'community', iconColor: '#2196F3', speed: 0.5, stakeAmount: 4 },
  { title: 'Disaster Relief Corps', slogan: 'Ready To Help', description: 'Rapid response volunteer network for natural disasters.', category: 'community', iconColor: '#FF5722', speed: 0.8, stakeAmount: 5 },
  // Politics (8)
  { title: 'Voter Registration Drive', slogan: 'Your Vote Matters', description: 'Registering 1 million new voters for the next election.', category: 'politics', iconColor: '#2196F3', speed: 0.6, stakeAmount: 5 },
  { title: 'Term Limits Now', slogan: 'Fresh Leadership', description: 'Advocating for congressional term limits through legislation.', category: 'politics', iconColor: '#F44336', speed: 0.7, stakeAmount: 6 },
  { title: 'Campaign Finance Reform', slogan: 'Clean Elections', description: 'Getting big money out of politics for fair elections.', category: 'politics', iconColor: '#4CAF50', speed: 0.5, stakeAmount: 4 },
  { title: 'Police Reform Coalition', slogan: 'Serve And Protect', description: 'Community-driven police accountability and reform measures.', category: 'politics', iconColor: '#607D8B', speed: 0.6, stakeAmount: 7 },
  { title: 'Healthcare Access Alliance', slogan: 'Care For All', description: 'Universal healthcare access regardless of income.', category: 'politics', iconColor: '#E91E63', speed: 0.5, stakeAmount: 5 },
  { title: 'Education Budget Coalition', slogan: 'Fund Our Schools', description: 'Increasing education funding at state and federal levels.', category: 'politics', iconColor: '#FF9800', speed: 0.4, stakeAmount: 4 },
  { title: 'Infrastructure Now', slogan: 'Build It Better', description: 'Modernizing roads, bridges, and public transit systems.', category: 'politics', iconColor: '#795548', speed: 0.5, stakeAmount: 6 },
  { title: 'Transparency Watchdog', slogan: 'Open Government', description: 'Demanding transparency and accountability in government.', category: 'politics', iconColor: '#9C27B0', speed: 0.6, stakeAmount: 3 },
];

// ─── Direct Message Templates ───────────────────────────────────────────────
const DM_TEMPLATES = [
  'Hey! Love your campaign, keep it up!',
  'Just joined your campaign, excited to contribute!',
  'What do you think about the latest poll?',
  'Great work on the environmental initiative!',
  'Want to collaborate on something?',
  'Your WAC strategy is impressive!',
  'Thanks for the follow! Let\'s connect.',
  'Have you checked out the new campaign features?',
  'How much WAC are you staking?',
  'I think we should rally more supporters.',
  'The platform is really growing fast!',
  'Nice slogan! Very creative.',
  'Are you going to vote on the community poll?',
  'I\'m thinking about starting my own campaign.',
  'What city are you based in?',
  'Let\'s organize a group vote!',
  'Your icon color is awesome!',
  'How long have you been on Wacting?',
  'The WAC economy is really interesting.',
  'I deposited more WAC today, feeling bullish!',
  'RAC protests are heating up!',
  'Should we join forces against that campaign?',
  'The leaderboard is getting competitive.',
  'I love the map visualization feature.',
  'What\'s your strategy for earning more WAC?',
  'Great poll question, I voted!',
  'Welcome to the platform!',
  'Can you share your campaign strategy?',
  'The community here is really supportive.',
  'Let me know if you need any help getting started.',
];

// ─── Poll Templates ──────────────────────────────────────────────────────────
const POLL_TEMPLATES = [
  { title: 'What should be our top priority?', options: ['Membership growth', 'Campaign awareness', 'Community events', 'Social media push'] },
  { title: 'Best time for community meetings?', options: ['Weekday evenings', 'Weekend mornings', 'Weekend afternoons'] },
  { title: 'Should we increase campaign stake?', options: ['Yes, double it', 'Small increase', 'Keep it the same', 'Decrease it'] },
  { title: 'Next campaign theme?', options: ['Education', 'Environment', 'Technology', 'Community'] },
  { title: 'How should we use campaign funds?', options: ['Marketing', 'Events', 'Charity donation', 'Platform development'] },
  { title: 'Vote on new campaign slogan', options: ['Together We Rise', 'Power To The People', 'Change Starts Here'] },
  { title: 'Should we merge with another campaign?', options: ['Yes', 'No', 'Need more info'] },
  { title: 'Rate our campaign progress', options: ['Excellent', 'Good', 'Needs improvement', 'Poor'] },
  { title: 'Best outreach strategy?', options: ['Social media', 'Word of mouth', 'Events', 'Partnerships'] },
  { title: 'How often should we poll?', options: ['Weekly', 'Bi-weekly', 'Monthly'] },
];

// ─── Seeder Logic ────────────────────────────────────────────────────────────

async function seedBots() {
  console.log('🤖 Starting Wacting Bot Seeder...\n');

  // Idempotency check
  const existingBots = await prisma.user.count({ where: { isBot: true } });
  if (existingBots >= 300) {
    console.log(`✅ ${existingBots} bots already exist. Skipping seed.`);
    return;
  }
  if (existingBots > 0) {
    console.log(`⚠ Found ${existingBots} partial bots. Cleaning up...`);
    // Delete in dependency order
    const botIds = (await prisma.user.findMany({ where: { isBot: true }, select: { id: true } })).map(u => u.id);
    await prisma.pollVote.deleteMany({ where: { voterId: { in: botIds } } });
    await prisma.directMessage.deleteMany({ where: { OR: [{ senderId: { in: botIds } }, { receiverId: { in: botIds } }] } });
    await prisma.follow.deleteMany({ where: { OR: [{ followerId: { in: botIds } }, { followingId: { in: botIds } }] } });
    await prisma.notification.deleteMany({ where: { userId: { in: botIds } } });
    // Get campaigns led by bots
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
  const createdUserIds: string[] = [];

  // ══════════════════════════════════════════════════════════════════════════
  // PHASE A: Create 300 Users
  // ══════════════════════════════════════════════════════════════════════════
  console.log('📦 Phase A: Creating 300 bot users...');
  for (let i = 0; i < bots.length; i++) {
    const bot = bots[i]!;
    const city = US_CITIES[bot.cityIdx]!;
    const emailName = bot.name.toLowerCase().replace(/[^a-z0-9]/g, '.').replace(/\.+/g, '.');
    const email = `${emailName}@wacting.com`;

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
            restrictedCountries: ['US'],
            restrictedCities: [city.city],
          },
        },
        wac: {
          create: {
            wacBalance: new Prisma.Decimal('100.000000'),
            isActive: true,
          },
        },
      },
    });

    // Record welcome bonus chain tx (sequential!)
    await prisma.$transaction(async (tx) => {
      await recordChainedTransaction(tx, {
        userId: user.id,
        amount: '100.000000',
        type: 'WAC_WELCOME_BONUS' as any,
        note: `Welcome bonus: 100 WAC (Early Adopter #${i + 1})`,
      });
    });

    createdUserIds.push(user.id);
    if ((i + 1) % 50 === 0) console.log(`   ✓ ${i + 1}/300 users created`);
  }
  console.log('   ✅ All 300 users created.\n');

  // ══════════════════════════════════════════════════════════════════════════
  // PHASE B: Create Campaigns (~62 campaigns)
  // ══════════════════════════════════════════════════════════════════════════
  console.log('🏴 Phase B: Creating campaigns...');
  const campaignIds: string[] = [];
  const campaignLeaders: Map<string, string> = new Map(); // campaignId → userId
  const campaignCategories: Map<string, string> = new Map(); // campaignId → category

  for (let i = 0; i < CAMPAIGN_TEMPLATES.length; i++) {
    const tmpl = CAMPAIGN_TEMPLATES[i]!;
    // Pick a leader from the matching category
    const categoryBots = bots.map((b, idx) => ({ ...b, userId: createdUserIds[idx]! }))
      .filter(b => b.category === tmpl.category);
    const leader = categoryBots[i % categoryBots.length]!;
    const stakeAmount = new Prisma.Decimal(tmpl.stakeAmount.toFixed(6));

    const campaign = await prisma.$transaction(async (tx) => {
      // Deduct WAC from leader
      await tx.userWac.update({
        where: { userId: leader.userId },
        data: {
          wacBalance: { decrement: stakeAmount },
          balanceUpdatedAt: new Date(),
        },
      });

      // Create campaign
      const c = await (tx as any).campaign.create({
        data: {
          leaderId: leader.userId,
          title: tmpl.title,
          slogan: tmpl.slogan,
          description: tmpl.description,
          iconColor: tmpl.iconColor,
          iconShape: leader.shapeIndex,
          speed: tmpl.speed,
          totalWacStaked: stakeAmount,
        },
      });

      // Leader as first member
      await (tx as any).campaignMember.create({
        data: {
          campaignId: c.id,
          userId: leader.userId,
          stakedWac: stakeAmount,
        },
      });

      // Chain tx
      await recordChainedTransaction(tx, {
        userId: leader.userId,
        amount: stakeAmount,
        type: 'WAC_CAMPAIGN_STAKE' as any,
        note: `Campaign created: "${tmpl.title}" — staked ${tmpl.stakeAmount} WAC`,
        campaignId: c.id,
      });

      return c;
    });

    campaignIds.push(campaign.id);
    campaignLeaders.set(campaign.id, leader.userId);
    campaignCategories.set(campaign.id, tmpl.category);
  }

  // Add members to campaigns (5-12 members each)
  console.log('   Adding members to campaigns...');
  const membershipMap: Map<string, Set<string>> = new Map(); // campaignId → Set of userIds
  for (const cid of campaignIds) {
    membershipMap.set(cid, new Set([campaignLeaders.get(cid)!]));
  }

  for (let cIdx = 0; cIdx < campaignIds.length; cIdx++) {
    const cid = campaignIds[cIdx]!;
    const cat = campaignCategories.get(cid)!;
    const numMembers = 5 + Math.floor(Math.random() * 8); // 5-12 members total (including leader)

    // Prefer same-category bots, but allow some cross-category
    const sameCatBots = bots.map((b, idx) => ({ ...b, userId: createdUserIds[idx]! }))
      .filter(b => b.category === cat && !membershipMap.get(cid)!.has(b.userId));
    const otherBots = bots.map((b, idx) => ({ ...b, userId: createdUserIds[idx]! }))
      .filter(b => b.category !== cat && !membershipMap.get(cid)!.has(b.userId));

    const candidates = [...sameCatBots.slice(0, numMembers), ...otherBots.slice(0, 3)];
    const toAdd = candidates.slice(0, numMembers - 1); // -1 because leader already in

    for (const member of toAdd) {
      const stakeAmount = new Prisma.Decimal((1 + Math.floor(Math.random() * 4)).toFixed(6));

      try {
        await prisma.$transaction(async (tx) => {
          await tx.userWac.update({
            where: { userId: member.userId },
            data: {
              wacBalance: { decrement: stakeAmount },
              balanceUpdatedAt: new Date(),
            },
          });

          await (tx as any).campaignMember.create({
            data: {
              campaignId: cid,
              userId: member.userId,
              stakedWac: stakeAmount,
            },
          });

          await tx.campaign.update({
            where: { id: cid },
            data: { totalWacStaked: { increment: stakeAmount } },
          });

          await recordChainedTransaction(tx, {
            userId: member.userId,
            amount: stakeAmount,
            type: 'WAC_CAMPAIGN_STAKE' as any,
            note: `Joined campaign — staked ${stakeAmount} WAC`,
            campaignId: cid,
          });
        });

        membershipMap.get(cid)!.add(member.userId);
      } catch {
        // Skip if unique constraint or balance issue
      }
    }
  }
  console.log(`   ✅ ${campaignIds.length} campaigns created with members.\n`);

  // ══════════════════════════════════════════════════════════════════════════
  // PHASE C: Social Graph (follows)
  // ══════════════════════════════════════════════════════════════════════════
  console.log('🤝 Phase C: Building social graph...');
  let followCount = 0;

  for (let i = 0; i < createdUserIds.length; i++) {
    const userId = createdUserIds[i]!;
    // Each bot follows 5-15 random others
    const numFollows = 5 + Math.floor(Math.random() * 11);
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
      // Skip duplicates silently
    }
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
  // PHASE D: Economy (campaign exits → RAC mint → protest pools)
  // ══════════════════════════════════════════════════════════════════════════
  console.log('💰 Phase D: Economy activation (exits + RAC)...');

  // Pick ~20 bots to exit campaigns (generating RAC)
  const exitCandidates: { userId: string; campaignId: string; stakedWac: Prisma.Decimal }[] = [];
  for (const [cid, members] of membershipMap.entries()) {
    const leaderId = campaignLeaders.get(cid)!;
    const nonLeaders = [...members].filter(id => id !== leaderId);
    // Pick 0-1 random non-leader members to exit
    if (nonLeaders.length > 2 && Math.random() < 0.4) {
      const exitUser = nonLeaders[Math.floor(Math.random() * nonLeaders.length)];
      const member = await (prisma as any).campaignMember.findUnique({
        where: { campaignId_userId: { campaignId: cid, userId: exitUser } },
      });
      if (member) {
        exitCandidates.push({ userId: exitUser, campaignId: cid, stakedWac: member.stakedWac });
      }
    }
  }

  let exitCount = 0;
  for (const exit of exitCandidates.slice(0, 20)) {
    const stakedWac = exit.stakedWac;
    const penalty = stakedWac.mul('0.30').toDecimalPlaces(6);
    const returnAmount = stakedWac.mul('0.70').toDecimalPlaces(6);
    const burnAmount = penalty.mul('0.50').toDecimalPlaces(6);
    const devAmount = penalty.sub(burnAmount);
    const racReward = BigInt(penalty.mul('2').floor().toFixed(0));

    try {
      await prisma.$transaction(async (tx) => {
        // Remove member
        await (tx as any).campaignMember.delete({
          where: { campaignId_userId: { campaignId: exit.campaignId, userId: exit.userId } },
        });

        // Decrease campaign staked WAC
        await tx.campaign.update({
          where: { id: exit.campaignId },
          data: { totalWacStaked: { decrement: stakedWac } },
        });

        // Return 70% WAC
        await tx.userWac.update({
          where: { userId: exit.userId },
          data: {
            wacBalance: { increment: returnAmount },
            balanceUpdatedAt: new Date(),
          },
        });

        // Burn + Dev treasury
        await tx.treasury.upsert({
          where: { id: 'singleton' },
          update: {
            burnedTotal: { increment: burnAmount },
            devBalance: { increment: devAmount },
          },
          create: {
            id: 'singleton',
            burnedTotal: burnAmount,
            devBalance: devAmount,
          },
        });

        // Mint RAC
        if (racReward > 0n) {
          await tx.userRac.upsert({
            where: { userId: exit.userId },
            update: { racBalance: { increment: racReward } },
            create: { userId: exit.userId, racBalance: racReward },
          });
        }

        // 4 chained transactions
        await recordChainedTransaction(tx, {
          userId: exit.userId, amount: returnAmount,
          type: 'WAC_CAMPAIGN_RETURN' as any,
          note: `Campaign exit — 70% returned`, campaignId: exit.campaignId,
        });
        await recordChainedTransaction(tx, {
          userId: exit.userId, amount: burnAmount,
          type: 'WAC_BURN' as any,
          note: `Campaign exit — 15% burned`, campaignId: exit.campaignId,
        });
        await recordChainedTransaction(tx, {
          userId: exit.userId, amount: devAmount,
          type: 'WAC_DEV_FEE' as any,
          note: `Campaign exit — 15% dev fee`, campaignId: exit.campaignId,
        });
        await recordChainedTransaction(tx, {
          userId: exit.userId, amount: racReward.toString(),
          type: 'RAC_MINTED' as any,
          note: `Campaign exit — ${racReward} RAC minted`, campaignId: exit.campaignId,
        });

        // History
        await (tx as any).campaignHistory.create({
          data: {
            userId: exit.userId,
            campaignId: exit.campaignId,
            joinedAt: new Date(Date.now() - 86400000 * 3),
            totalEarned: returnAmount,
          },
        });
      });

      membershipMap.get(exit.campaignId)!.delete(exit.userId);
      exitCount++;
    } catch (err) {
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
    // Pick a random campaign to protest (not their own)
    const userCampaigns = new Set<string>();
    for (const [cid, members] of membershipMap.entries()) {
      if (members.has(holder.userId)) userCampaigns.add(cid);
    }
    const protestable = campaignIds.filter(cid => !userCampaigns.has(cid));
    if (protestable.length === 0) continue;

    const targetCampaignId = protestable[Math.floor(Math.random() * protestable.length)];
    const depositAmount = BigInt(Math.min(Number(holder.racBalance), 1 + Math.floor(Math.random() * 3)));

    try {
      await prisma.$transaction(async (tx) => {
        // Find or create pool
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
            data: {
              totalBalance: { increment: depositAmount },
              participantCount: { increment: 1 },
            },
          });
        }

        // Add participant
        await tx.racPoolParticipant.create({
          data: {
            poolId: pool.id,
            userId: holder.userId,
            contribution: depositAmount,
          },
        });

        // Deduct from user RAC
        await tx.userRac.update({
          where: { userId: holder.userId },
          data: { racBalance: { decrement: depositAmount } },
        });

        // Chain tx
        await recordChainedTransaction(tx, {
          userId: holder.userId,
          amount: depositAmount.toString(),
          type: 'RAC_POOL_DEPOSIT' as any,
          note: `Deposited ${depositAmount} RAC into protest pool`,
          campaignId: targetCampaignId,
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

  for (let cIdx = 0; cIdx < campaignIds.length; cIdx++) {
    const cid = campaignIds[cIdx];
    const leaderId = campaignLeaders.get(cid)!;
    const members = [...(membershipMap.get(cid) || [])];

    // Create 0-1 polls per campaign
    if (Math.random() < 0.65 && members.length >= 3) {
      const tmpl = POLL_TEMPLATES[cIdx % POLL_TEMPLATES.length];
      const endsAt = new Date(Date.now() + 86400000 * (1 + Math.floor(Math.random() * 3)));

      const poll = await (prisma as any).campaignPoll.create({
        data: {
          campaignId: cid,
          title: tmpl.title,
          description: `Poll for ${CAMPAIGN_TEMPLATES[cIdx % CAMPAIGN_TEMPLATES.length].title}`,
          endsAt,
          options: {
            create: tmpl.options.map(text => ({ text })),
          },
        },
        include: { options: true },
      });
      pollCount++;

      // Members vote
      for (const memberId of members) {
        if (memberId === leaderId && Math.random() < 0.3) continue; // Leader sometimes skips
        const randomOption = poll.options[Math.floor(Math.random() * poll.options.length)];

        // Get member's staked WAC for weight
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

  // Generate ~150 messages between followers/campaign mates
  for (let i = 0; i < 150; i++) {
    const senderIdx = Math.floor(Math.random() * createdUserIds.length);
    let receiverIdx = Math.floor(Math.random() * createdUserIds.length);
    while (receiverIdx === senderIdx) {
      receiverIdx = Math.floor(Math.random() * createdUserIds.length);
    }
    messages.push({
      senderId: createdUserIds[senderIdx],
      receiverId: createdUserIds[receiverIdx],
      content: DM_TEMPLATES[i % DM_TEMPLATES.length],
    });
  }

  await prisma.directMessage.createMany({ data: messages });
  console.log(`   ✅ ${messages.length} direct messages created.\n`);

  // ══════════════════════════════════════════════════════════════════════════
  // DONE
  // ══════════════════════════════════════════════════════════════════════════
  console.log('════════════════════════════════════════════');
  console.log('🎉 Bot seeding complete!');
  console.log(`   👤 Users:      300`);
  console.log(`   🏴 Campaigns:  ${campaignIds.length}`);
  console.log(`   🤝 Follows:    ${followCount}`);
  console.log(`   🚪 Exits:      ${exitCount}`);
  console.log(`   ⚔ RAC Pools:  ${poolCount}`);
  console.log(`   🗳 Polls:      ${pollCount}`);
  console.log(`   ✉ Messages:   ${messages.length}`);
  console.log('════════════════════════════════════════════\n');
}

// ─── Entry Point ─────────────────────────────────────────────────────────────
seedBots()
  .catch(err => {
    console.error('❌ Seed failed:', err);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
