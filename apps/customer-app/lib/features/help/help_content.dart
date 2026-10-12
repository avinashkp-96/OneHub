import 'package:onehub_shared/onehub_shared.dart';

// Placeholder support content: no support desk or help-centre exists yet, so
// the contact details are made up and the answers describe the flow as built.
// Replace with real contacts and reviewed answers before release.
const customerSupportEmail = 'support@onehub.example';
const customerSupportPhone = '+91 90000 00000';

const customerFaqs = [
  FaqItem('How do I post a request?',
      'Pick a service from the home screen, describe the job, choose a date and the providers you want to hear from.'),
  FaqItem('How do bids work?',
      'Providers send you a price range. Compare them, then confirm the one you want.'),
  FaqItem('When do I see a provider\'s contact details?',
      'After you confirm a provider and they unlock your contact, you can call or message each other.'),
  FaqItem('How do I rate a job?',
      'Open the finished job under My requests and tap Rate provider.'),
  FaqItem('Can I change my phone number?',
      'Not yet. Changing it needs a new OTP, which is not available in the app.'),
];
