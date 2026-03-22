/**
 * UI çeviri scripti — MyMemory ücretsiz API kullanır
 * Çalıştır: node scripts/generate_translations.mjs
 * Çıktı: scripts/translations_output.dart
 */

import { writeFileSync } from 'fs';

// ── Kaynak: İngilizce metinler ────────────────────────────────────────────────
const EN = {
  'login': 'Log In',
  'register': 'Sign Up',
  'email': 'Email',
  'password': 'Password',
  'password_confirm': 'Confirm Password',
  'no_account': "Don't have an account? Sign Up",
  'has_account': 'Already have an account? Log In',
  'lost_password': 'Forgot your password?',
  'login_failed': 'Login failed.',
  'email_required': 'Email is required.',
  'password_required': 'Password is required.',
  'valid_email': 'Please enter a valid email address.',
  'password_min': 'Password must be at least 6 characters.',
  'passwords_mismatch': 'Passwords do not match.',
  'terms_required': 'You must accept the terms of use.',
  'activation_sent': 'Activation code has been sent to {email}.',
  'new_code_sent': 'New code sent.',
  'error_occurred': 'An error occurred.',
  'connection_error': 'Connection error.',
  'terms_agree': 'I have read and accept the terms of use.',
  'read_terms': 'Read Terms',
  'terms_title': 'Terms of Use',
  'terms_accept': 'I Have Read and Accept',
  'email_verification': 'Email Verification',
  'verification_hint': 'Enter the 6-digit code sent to your email.',
  'verify': 'VERIFY',
  'resend_code': 'Resend code',
  'go_back': 'Go back',
  'enter_6digit': 'Enter the 6-digit activation code.',
  'world': 'WORLD',
  'feed': 'FEED',
  'profile_nav': 'PROFILE',
  'profile': 'Profile',
  'wallet': 'WALLET',
  'profile_tab': 'PROFILE',
  'about': 'About',
  'about_placeholder': 'Tell about yourself briefly...',
  'no_bio_own': 'No bio added yet.',
  'no_bio_other': 'No bio available.',
  'save': 'Save',
  'cancel': 'Cancel',
  'social_media': 'Social Media',
  'not_connected': 'Not connected',
  'follow': 'Follow',
  'unfollow': 'Unfollow',
  'following_you': 'Following',
  'platform_follow': 'Platform follow',
  'add': 'Add',
  'link_title': '{platform} Link',
  'enter_profile_link': 'Enter your profile link',
  'link_update_failed': 'Could not update link.',
  'only_letters': 'Use only letters and spaces.',
  'name_update_failed': 'Could not update name.',
  'bio_update_failed': 'Could not update bio.',
  'user': 'User',
  'settings': 'Settings',
  'location_settings': 'Location Settings',
  'location_on': 'Your location is visible on the map',
  'location_off': 'Location off — you are not visible on the map',
  'location_offset': 'Location Offset (meters)',
  'location_offset_desc': 'Your location will be offset by this many meters for privacy',
  'location_enabled': 'Location enabled',
  'location_denied': 'Location permission denied',
  'offset_set': 'Offset set to {offset}m',
  'terms_of_use': 'Terms of Use',
  'terms_view': 'View terms of use',
  'privacy_policy': 'Privacy Policy',
  'privacy_view': 'View privacy policy',
  'privacy_coming': 'Privacy policy content will be added soon.',
  'notification_settings': 'Notification Settings',
  'notification_manage': 'Manage notification preferences',
  'notification_coming': 'Notification settings will be available soon.',
  'feedback': 'Feedback',
  'feedback_send': 'Send feedback',
  'feedback_request': 'Request',
  'feedback_complaint': 'Complaint',
  'feedback_suggestion': 'Suggestion',
  'feedback_subject': 'Subject',
  'feedback_message': 'Write your message...',
  'feedback_sent': 'Your feedback has been received. Thank you!',
  'send': 'Send',
  'freeze_account': 'Freeze Account',
  'freeze_desc': 'Temporarily freeze your account',
  'freeze_confirm': 'Are you sure you want to freeze your account?',
  'freeze_when': 'When your account is frozen:',
  'freeze_1': 'Your profile will be invisible to other users',
  'freeze_2': 'Your campaigns will be paused',
  'freeze_3': 'You will not receive notifications',
  'freeze_4': 'You can reactivate at any time',
  'freeze': 'Freeze',
  'freeze_coming': 'Account freezing will be available soon.',
  'delete_account': 'Delete Account',
  'delete_desc': 'Permanently delete your account',
  'delete_irreversible': 'This action cannot be undone!',
  'delete_when': 'When your account is deleted:',
  'delete_1': 'All your data will be permanently deleted',
  'delete_2': 'Your campaigns will be closed',
  'delete_3': 'Your WAC and RAC balance will be reset',
  'delete_4': 'This action cannot be undone',
  'delete_permanent': 'Permanently Delete Account',
  'delete_coming': 'Account deletion will be available soon.',
  'blocked_users': 'Blocked Users',
  'blocked_manage': 'Manage block list',
  'blocked_empty': 'Your blocked users list is empty.',
  'help': 'Help & Support',
  'help_desc': 'FAQ and contact',
  'faq': 'Frequently Asked Questions',
  'faq_coming': 'Coming soon.',
  'contact': 'Contact',
  'logout': 'Log Out',
  'logout_confirm': 'Are you sure you want to log out?',
  'ok': 'OK',
  'language': 'Language',
  'language_desc': 'Change app language',
  'language_select': 'Language Selection',
  'wallet_label': 'Wallet',
  'wallet_copied': 'Wallet ID copied!',
  'send_token': 'Send',
  'receive_token': 'Receive',
  'target_wallet': 'Target wallet ID',
  'amount': 'Amount',
  'transfer_success': 'Transfer successful!',
  'transfer_failed': 'Transfer failed: {error}',
  'tx_history': 'Transaction History',
  'no_tx': 'No transactions yet.',
  'notifications': 'Notifications',
  'mark_all_read': 'Mark All Read',
  'no_notifications': 'No notifications',
  'now': 'now',
  'campaigns': 'CAMPAIGNS',
  'global': 'GLOBAL',
  'create_campaign': 'Create Campaign',
  'campaign': 'Campaign',
  'expired': 'Expired',
  'ended': 'Ended',
  'joined': 'Joined',
  'left': 'Left',
  'earned': 'Earned',
  'leader': 'Leader',
  'participants': 'Members',
  'total_stake': 'Total Stake',
  'my_stake': 'My Stake',
  'stake_ratio': 'Stake Ratio',
  'add_stake': 'Add Stake',
  'add_wac_stake': 'Add WAC Stake',
  'leave_campaign': 'Leave Campaign',
  'leaving': 'Leaving...',
  'left_campaign': 'You have left the campaign.',
  'vote': 'VOTE',
  'people': 'people',
  'all': 'All',
  'support': 'Support',
  'protest': 'Protest',
  'reform': 'Reform',
  'emergency': 'Emergency',
  'support_label': 'Support / Praise',
  'support_desc': 'Support a development, technology, or brand.',
  'protest_label': 'Protest / Objection',
  'protest_desc': 'Call to stop an application, law, or situation.',
  'reform_label': 'Solution / Reform',
  'reform_desc': 'Present a concrete project, bill, or alternative.',
  'emergency_label': 'Emergency Call',
  'emergency_desc': 'Emergency situations requiring immediate intervention.',
  'emergency_settings': 'Emergency Settings',
  'wac_pool': 'WAC Pool',
  'logo_area': 'Logo Area',
  'end_time': 'End',
  'wac_spend': 'WAC Spend',
  'extend_time': 'Extend Time',
  'enlarge_logo': 'Enlarge Logo',
  'success': 'Success',
  'campaign_speed': 'Campaign Speed',
  'fixed': 'Fixed',
  'icon_fixed': 'Icon stays fixed on the map',
  'save_speed': 'Save Speed',
  'no_selection': 'No selection',
  'emergency_default': 'Emergency',
  'filter_all_campaigns': 'All Campaigns',
  'filter_protest': 'Protest',
  'filter_reform': 'Reform',
  'filter_support': 'Support',
  'filter_emergency': 'Emergency',
  'campaign_detail': 'Campaign Detail',
  'campaign_leader': 'Leader',
  'campaign_members': 'Members',
  'campaign_total_wac': 'Total WAC',
  'campaign_total_rac': 'Total RAC',
  'campaign_type': 'Type',
  'campaign_loading': 'Loading...',
  'campaign_error': 'Could not load campaign info.',
  'penalty_total': 'Total Stake',
  'rac_reward': 'RAC Reward',
  'leave': 'Leave',
  'movement_speed': 'Movement Speed',
  'movement_speed_desc': 'Adjust icon movement speed on map (0 = fixed, 0.5 = default)',
  'icon_stays_fixed': 'Icon stays fixed, does not move.',
  'translate': 'Translate',
  'translating': 'Translating...',
  'show_original': 'Show Original',
};

// ── Hedef diller (en ve tr hariç) ─────────────────────────────────────────────
const LANGS = ['es','fr','de','pt','it','ru','ar','zh','ja','ko','hi','id','nl','pl','uk','fa','vi','sw'];

// ── MyMemory API çağrısı ───────────────────────────────────────────────────────
async function translateText(text, targetLang) {
  // Placeholder gibi {email} içeren metinleri koru
  const hasPlaceholder = /\{[^}]+\}/.test(text);
  let safeText = text;
  const placeholders = [];

  if (hasPlaceholder) {
    safeText = text.replace(/\{[^}]+\}/g, (m) => {
      const idx = placeholders.length;
      placeholders.push(m);
      return `PLACEHOLDER${idx}`;
    });
  }

  const url = `https://api.mymemory.translated.net/get?q=${encodeURIComponent(safeText)}&langpair=en|${targetLang}`;
  const res = await fetch(url);
  const json = await res.json();

  if (json.responseStatus !== 200) return null;
  let translated = json.responseData?.translatedText;
  if (!translated) return null;

  // Placeholder'ları geri koy
  if (hasPlaceholder) {
    placeholders.forEach((p, i) => {
      translated = translated.replace(`PLACEHOLDER${i}`, p);
    });
  }

  return translated;
}

// ── Dart string escape ────────────────────────────────────────────────────────
function escapeDart(str) {
  return str.replace(/\\/g, '\\\\').replace(/'/g, "\\'");
}

// ── Ana döngü ─────────────────────────────────────────────────────────────────
async function main() {
  const results = {};

  for (const lang of LANGS) {
    console.log(`\n🌍 ${lang} çeviriliyor...`);
    results[lang] = {};
    const keys = Object.keys(EN);

    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      const text = EN[key];

      try {
        const translated = await translateText(text, lang);
        results[lang][key] = translated ?? text; // fallback: İngilizce
        process.stdout.write(`  [${i + 1}/${keys.length}] ${key}: OK\r`);
      } catch (e) {
        results[lang][key] = text;
        process.stdout.write(`  [${i + 1}/${keys.length}] ${key}: HATA\r`);
      }

      // Rate limit — MyMemory 1 saniye/istek
      await new Promise(r => setTimeout(r, 350));
    }

    console.log(`  ✅ ${lang} tamamlandı (${keys.length} anahtar)`);
  }

  // ── Dart Map çıktısı ─────────────────────────────────────────────────────
  let output = `// ── OTOMATİK ÜRETİLDİ: generate_translations.mjs ──────────────────────────\n`;
  output += `// Bu bloğu locale_service.dart içindeki _translations Map'ine ekleyin.\n\n`;

  for (const lang of LANGS) {
    output += `    '${lang}': {\n`;
    for (const [key, val] of Object.entries(results[lang])) {
      output += `      '${key}': '${escapeDart(val)}',\n`;
    }
    output += `    },\n\n`;
  }

  writeFileSync('scripts/translations_output.dart', output, 'utf8');
  console.log('\n✅ Tamamlandı! scripts/translations_output.dart dosyasına yazıldı.');
  console.log('   locale_service.dart içindeki eski dil bloklarını bu çıktıyla değiştirin.');
}

main().catch(console.error);
