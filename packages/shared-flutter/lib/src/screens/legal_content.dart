import 'info_screen.dart';

// PLACEHOLDER legal text. Nothing here has been reviewed by counsel and none
// of it is a real agreement; it exists so the Terms and Privacy screens have
// something to show and so the wording can be swapped in one place. Replace
// both lists (and drop [legalPlaceholderNotice]) with the approved documents
// before any public release.

const legalPlaceholderNotice =
    'Draft text for development. The final terms will replace this.';

const onehubTermsSections = [
  InfoSection('Using OneHub',
      'OneHub connects customers with local service providers. You are responsible for the accuracy of the details you give and for what you agree with the other party.'),
  InfoSection('Requests and bids',
      'Customers post requests and providers respond with a price range. A bid is not a booking until the customer confirms a provider.'),
  InfoSection('Fees',
      'Providers pay a fee to unlock a customer\'s contact details and may pay a subscription. Fees are shown before you pay.'),
  InfoSection('Ratings and conduct',
      'Be honest and respectful in ratings and messages. Accounts that abuse the service may be suspended.'),
];

const onehubPrivacySections = [
  InfoSection('What we collect',
      'Your name, phone number and email, the requests you post or respond to, and your approximate area.'),
  InfoSection('How it is used',
      'To match requests with providers, send you updates, and keep the service safe. Contact details are shared only after a provider is confirmed.'),
  InfoSection('Your choices',
      'You can edit your details and turn notifications on or off in the app, and ask us to delete your account.'),
];
