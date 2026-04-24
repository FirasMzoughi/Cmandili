import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in first.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await Supabase.instance.client.from('support_tickets').insert({
        'user_id': userId,
        'subject': _subjectController.text.trim(),
        'message': _messageController.text.trim(),
        'status': 'open',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Support ticket sent! We will contact you soon.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send ticket: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'How can we help you?',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Fill out the form below and our team will get back to you within 24 hours.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              TextFormField(
                controller: _subjectController,
                decoration: InputDecoration(
                  labelText: 'Subject',
                  prefixIcon: const Icon(Icons.title, color: AppColors.primary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) => value!.isEmpty ? 'Please enter a subject' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _messageController,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: 'Message',
                  alignLabelWithHint: true,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 100),
                    child: Icon(Icons.message_outlined, color: AppColors.primary),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) => value!.isEmpty ? 'Please enter your message' : null,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _submitting ? null : _submitTicket,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Submit Ticket',
                        style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 30),
              const _ContactOption(
                icon: Icons.email_outlined,
                title: 'Email Us',
                subtitle: 'support@cmandili.com',
              ),
              const _ContactOption(
                icon: Icons.phone_outlined,
                title: 'Call Us',
                subtitle: '+216 71 123 456',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ContactOption({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
