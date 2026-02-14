import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class EmailService {
  final String _username = 'intellihome.2026@gmail.com';
  final String _password = 'tunl tbpx enwn qoif';
  
  Future<bool> sendOtpEmail(String recipientEmail, String otp) async {
    final smtpServer = gmail(_username, _password);

    final message = Message()
      ..from = Address(_username, 'IntelliHome Security') 
      ..recipients.add(recipientEmail)
      ..subject = 'IntelliHome: Verification Code'
      ..text = 'Your One-Time Password (OTP) is: $otp\n\n'
               'Please enter this code in the app to verify your identity.\n\n'
               '- The IntelliHome Team'; 

    try {
      final sendReport = await send(message, smtpServer);
      print('Message sent: ${sendReport.toString()}');
      return true;
    } on MailerException catch (e) {
      print('Message not sent.');
      print(e.toString());
      return false;
    }
  }
}