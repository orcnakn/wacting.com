import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../core/services/api_service.dart';
import '../../core/services/locale_service.dart';

class StorySection extends StatefulWidget {
  final bool isOwnProfile;
  final String userId;

  const StorySection({Key? key, required this.isOwnProfile, required this.userId}) : super(key: key);

  @override
  State<StorySection> createState() => _StorySectionState();
}

class _StorySectionState extends State<StorySection> {
  List<dynamic> _stories = [];
  bool _loading = true;
  bool _creating = false;

  final _contentController = TextEditingController();
  final _youtubeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStories();
  }

  @override
  void dispose() {
    _contentController.dispose();
    _youtubeController.dispose();
    super.dispose();
  }

  Future<void> _loadStories() async {
    try {
      final stories = widget.isOwnProfile
          ? await apiService.getMyStories()
          : await apiService.getUserStories(widget.userId);
      if (mounted) setState(() { _stories = stories; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createStory() async {
    final content = _contentController.text.trim();
    final youtubeUrl = _youtubeController.text.trim();
    if (content.isEmpty && youtubeUrl.isEmpty) return;

    setState(() => _creating = true);
    try {
      await apiService.createStory(
        content: content.isNotEmpty ? content : null,
        youtubeUrl: youtubeUrl.isNotEmpty ? youtubeUrl : null,
      );
      _contentController.clear();
      _youtubeController.clear();
      await _loadStories();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Story olusturulamadi'), backgroundColor: AppColors.accentRed),
        );
      }
    }
    if (mounted) setState(() => _creating = false);
  }

  void _showPublishDialog(String storyId) {
    final selectedPlatforms = <String>{};
    final platforms = ['instagram', 'twitter', 'facebook', 'tiktok', 'linkedin'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Yayinla', style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Hangi platformlarda yayinlamak istiyorsun?',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 12),
              ...platforms.map((p) => CheckboxListTile(
                title: Text(p[0].toUpperCase() + p.substring(1),
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                value: selectedPlatforms.contains(p),
                activeColor: AppColors.accentTeal,
                onChanged: (val) {
                  setDialogState(() {
                    if (val == true) selectedPlatforms.add(p);
                    else selectedPlatforms.remove(p);
                  });
                },
                dense: true,
                contentPadding: EdgeInsets.zero,
              )),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  setDialogState(() {
                    if (selectedPlatforms.length == platforms.length) {
                      selectedPlatforms.clear();
                    } else {
                      selectedPlatforms.addAll(platforms);
                    }
                  });
                },
                child: Text(
                  selectedPlatforms.length == platforms.length ? 'Hepsini Kaldir' : 'Hepsini Sec',
                  style: TextStyle(color: AppColors.accentBlue, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t('cancel'), style: TextStyle(color: AppColors.textTertiary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentTeal, foregroundColor: Colors.white),
              onPressed: () async {
                if (selectedPlatforms.isEmpty) return;
                try {
                  await apiService.publishStory(storyId, selectedPlatforms.toList());
                  Navigator.pop(ctx);
                  _loadStories();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Story yayinlandi!'), backgroundColor: AppColors.accentGreen),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Yayinlama basarisiz'), backgroundColor: AppColors.accentRed),
                  );
                }
              },
              child: Text('Yayinla'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteStory(String id) async {
    try {
      await apiService.deleteStory(id);
      _loadStories();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.auto_stories, color: AppColors.accentBlue, size: 18),
          const SizedBox(width: 8),
          Text('Story', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 12),

        // Create story form (own profile only)
        if (widget.isOwnProfile) ...[
          TextField(
            controller: _contentController,
            maxLines: 3,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Bir seyler yaz...',
              hintStyle: TextStyle(color: AppColors.textTertiary),
              filled: true,
              fillColor: AppColors.surfaceWhite,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.borderLight)),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _youtubeController,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'YouTube linki (opsiyonel)',
              hintStyle: TextStyle(color: AppColors.textTertiary),
              prefixIcon: Icon(Icons.play_circle_outline, color: AppColors.accentRed, size: 18),
              filled: true,
              fillColor: AppColors.surfaceWhite,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.borderLight)),
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            // TODO: Image/Video picker buttons can be added here
            const Spacer(),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onPressed: _creating ? null : _createStory,
              icon: _creating
                  ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Icon(Icons.save, size: 16),
              label: Text('Kaydet', style: TextStyle(fontSize: 12)),
            ),
          ]),
          const SizedBox(height: 16),
        ],

        // Stories list
        if (_loading)
          Center(child: Padding(
            padding: const EdgeInsets.all(16),
            child: CircularProgressIndicator(color: AppColors.accentBlue, strokeWidth: 2),
          ))
        else if (_stories.isEmpty)
          Center(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              widget.isOwnProfile ? 'Henuz story olusturmadin.' : 'Henuz story yok.',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ))
        else
          ..._stories.map<Widget>((story) {
            final content = (story['content'] ?? '') as String;
            final youtubeUrl = (story['youtubeUrl'] ?? '') as String;
            final isPublished = story['isPublished'] == true;
            final publishedTo = (story['publishedTo'] as List?)?.cast<String>() ?? [];
            final storyId = story['id'] as String;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isPublished ? AppColors.accentGreen.withOpacity(0.3) : AppColors.borderLight,
                  width: 0.5,
                ),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (content.isNotEmpty)
                  Text(content, style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                if (youtubeUrl.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.play_circle_outline, color: AppColors.accentRed, size: 16),
                    const SizedBox(width: 4),
                    Expanded(child: Text(youtubeUrl, style: TextStyle(color: AppColors.accentBlue, fontSize: 11),
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                ],
                const SizedBox(height: 8),
                Row(children: [
                  if (isPublished)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accentGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.check_circle, color: AppColors.accentGreen, size: 12),
                        const SizedBox(width: 3),
                        Text(publishedTo.isNotEmpty ? publishedTo.join(', ') : 'Yayinlandi',
                            style: TextStyle(color: AppColors.accentGreen, fontSize: 10)),
                      ]),
                    )
                  else if (widget.isOwnProfile)
                    GestureDetector(
                      onTap: () => _showPublishDialog(storyId),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.accentTeal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.accentTeal.withOpacity(0.3)),
                        ),
                        child: Text('Yayinla', style: TextStyle(color: AppColors.accentTeal, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  const Spacer(),
                  if (widget.isOwnProfile)
                    GestureDetector(
                      onTap: () => _deleteStory(storyId),
                      child: Icon(Icons.delete_outline, color: AppColors.textTertiary, size: 16),
                    ),
                ]),
              ]),
            );
          }),
      ]),
    );
  }
}
