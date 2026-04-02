import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../models/media_info.dart';
import '../widgets/result_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;
  MediaInfo? _info;
  String? _currentUrl;

  Future<void> _fetch() async {
    final url = _controller.text.trim();
    if (url.isEmpty) return;

    setState(() { _loading = true; _error = null; _info = null; });

    try {
      final info = await ApiService.fetchInfo(url);
      setState(() { _info = info; _currentUrl = url; });
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); });
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              _buildHeader(),
              const SizedBox(height: 28),
              _buildInputCard(),
              if (_error != null) ...[
                const SizedBox(height: 12),
                _buildError(),
              ],
              if (_info != null && _currentUrl != null) ...[
                const SizedBox(height: 16),
                ResultCard(info: _info!, url: _currentUrl!),
              ],
              const SizedBox(height: 40),
              _buildHowItWorks(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.download_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 10),
            const Text('LinkDrop',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700,
                color: Color(0xFF6C63FF))),
          ],
        ),
        const SizedBox(height: 8),
        const Text('Paste any shared link. Download the content.',
          style: TextStyle(color: Color(0xFF888899), fontSize: 14)),
      ],
    );
  }

  Widget _buildInputCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A24),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2E2E3E)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  onSubmitted: (_) => _fetch(),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Paste a YouTube, TikTok, Instagram link...',
                    hintStyle: const TextStyle(color: Color(0xFF888899), fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFF22222F),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF2E2E3E)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF2E2E3E)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF6C63FF)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Color(0xFF888899), size: 18),
                          onPressed: () => setState(() => _controller.clear()),
                        )
                      : null,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _loading ? null : _fetch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  child: _loading
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Fetch', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildChips(),
        ],
      ),
    );
  }

  Widget _buildChips() {
    const platforms = ['YouTube','TikTok','Instagram','Twitter','Reddit','Vimeo','Direct Files'];
    return Wrap(
      spacing: 6, runSpacing: 6,
      children: platforms.map((p) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF22222F),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF2E2E3E)),
        ),
        child: Text(p, style: const TextStyle(color: Color(0xFF888899), fontSize: 11)),
      )).toList(),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF87171).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF87171).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFF87171), size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFF87171), fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildHowItWorks() {
    final steps = [
      ('1', 'Paste any shared link into the input above'),
      ('2', 'We detect the platform and fetch available formats'),
      ('3', 'Choose your format and download instantly'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('HOW IT WORKS',
          style: TextStyle(color: Color(0xFF888899), fontSize: 11, letterSpacing: 1.2)),
        const SizedBox(height: 12),
        ...steps.map((s) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A24),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2E2E3E)),
            ),
            child: Row(
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(color: const Color(0xFF6C63FF), shape: BoxShape.circle),
                  child: Center(child: Text(s.$1,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13))),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(s.$2,
                  style: const TextStyle(color: Color(0xFF888899), fontSize: 13))),
              ],
            ),
          ),
        )),
      ],
    );
  }
}
