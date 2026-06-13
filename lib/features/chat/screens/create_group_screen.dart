import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/services/local_network_service.dart';
import '../../auth/models/user_model.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final LocalNetworkService _networkService = LocalNetworkService();
  final _groupNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // قائمة بكل الأصدقاء المتاحين للإضافة
  List<User> _availableFriends = [];
  // قائمة بالمعرفات (IDs) للأصدقاء الذين تم اختيارهم
  final List<String> _selectedFriendIds = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  // تحميل قائمة الأصدقاء من الخدمة
  void _loadFriends() {
    // نحصل على معرفات كل الأصدقاء
    final friendIds = _networkService.getFriendIds();
    // نحول المعرفات إلى كائنات User كاملة
    _availableFriends = friendIds
        .map((id) => User(
      id: id,
      username: _networkService.getUsernameFromDirectory(id),
    ))
        .toList();
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  // دالة لإنشاء المجموعة
  Future<void> _createGroup() async {
    // التحقق من صحة اسم المجموعة ومن اختيار عضو واحد على الأقل
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedFriendIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب اختيار عضو واحد على الأقل.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // استدعاء الدالة لإنشاء المجموعة من الخدمة
      await _networkService.createGroup(
        _groupNameController.text.trim(),
        _selectedFriendIds,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إنشاء مجموعة "${_groupNameController.text.trim()}" بنجاح!'),
            backgroundColor: Colors.green,
          ),
        );
        // العودة إلى الشاشة الرئيسية بعد الإنشاء
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء إنشاء المجموعة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إنشاء مجموعة جديدة'),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // حقل إدخال اسم المجموعة
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextFormField(
                controller: _groupNameController,
                decoration: InputDecoration(
                  labelText: 'اسم المجموعة',
                  prefixIcon: const Icon(Iconsax.edit),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'يرجى إدخال اسم للمجموعة.';
                  }
                  return null;
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'اختر الأعضاء:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            // قائمة الأصدقاء للاختيار منهم
            Expanded(
              child: _availableFriends.isEmpty
                  ? const Center(child: Text('ليس لديك أصدقاء لإضافتهم.'))
                  : ListView.builder(
                itemCount: _availableFriends.length,
                itemBuilder: (context, index) {
                  final friend = _availableFriends[index];
                  final isSelected = _selectedFriendIds.contains(friend.id);

                  return CheckboxListTile(
                    secondary: CircleAvatar(
                      child: Text(friend.username.isNotEmpty
                          ? friend.username.substring(0, 1).toUpperCase()
                          : '?'),
                    ),
                    title: Text(friend.username),
                    value: isSelected,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          _selectedFriendIds.add(friend.id);
                        } else {
                          _selectedFriendIds.remove(friend.id);
                        }
                      });
                    },
                  );
                },
              ),
            ),
            // زر إنشاء المجموعة
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  icon: const Icon(Iconsax.add_square),
                  label: const Text('إنشاء المجموعة', style: TextStyle(fontSize: 18)),
                  onPressed: _isLoading ? null : _createGroup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
