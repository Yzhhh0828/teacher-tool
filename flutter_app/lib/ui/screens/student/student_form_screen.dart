import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design/tokens.dart';
import '../../../providers/student_provider.dart';
import '../../../data/models/student.dart';

class StudentFormScreen extends ConsumerStatefulWidget {
  final int classId;
  final Student? student;

  const StudentFormScreen({
    super.key,
    required this.classId,
    this.student,
  });

  @override
  ConsumerState<StudentFormScreen> createState() => _StudentFormScreenState();
}

class _StudentFormScreenState extends ConsumerState<StudentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _parentPhoneController;
  late final TextEditingController _remarksController;
  late final TextEditingController _studentNoController;
  late final TextEditingController _birthdayController;
  late final TextEditingController _parentNameController;
  late final TextEditingController _addressController;
  late final TextEditingController _homePhoneController;
  late final TextEditingController _hobbiesController;
  late final TextEditingController _healthController;
  late final TextEditingController _emergencyContactController;
  late final TextEditingController _descriptionController;
  String _gender = 'male';

  @override
  void initState() {
    super.initState();
    final s = widget.student;
    _nameController = TextEditingController(text: s?.name ?? '');
    _phoneController = TextEditingController(text: s?.phone ?? '');
    _parentPhoneController = TextEditingController(text: s?.parentPhone ?? '');
    _remarksController = TextEditingController(text: s?.remarks ?? '');
    _studentNoController = TextEditingController(text: s?.studentNo ?? '');
    _birthdayController = TextEditingController(text: s?.birthday ?? '');
    _parentNameController = TextEditingController(text: s?.parentName ?? '');
    _addressController = TextEditingController(text: s?.address ?? '');
    _homePhoneController = TextEditingController(text: s?.homePhone ?? '');
    _hobbiesController = TextEditingController(text: s?.hobbies ?? '');
    _healthController = TextEditingController(text: s?.health ?? '');
    _emergencyContactController = TextEditingController(text: s?.emergencyContact ?? '');
    _descriptionController = TextEditingController(text: s?.description ?? '');
    _gender = s?.gender ?? 'male';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _parentPhoneController.dispose();
    _remarksController.dispose();
    _studentNoController.dispose();
    _birthdayController.dispose();
    _parentNameController.dispose();
    _addressController.dispose();
    _homePhoneController.dispose();
    _hobbiesController.dispose();
    _healthController.dispose();
    _emergencyContactController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String? _trimOrNull(TextEditingController c) {
    final v = c.text.trim();
    return v.isEmpty ? null : v;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final student = Student(
      id: widget.student?.id ?? 0,
      classId: widget.classId,
      name: _nameController.text.trim(),
      gender: _gender,
      phone: _trimOrNull(_phoneController),
      parentPhone: _trimOrNull(_parentPhoneController),
      remarks: _trimOrNull(_remarksController),
      createdAt: widget.student?.createdAt ?? DateTime.now(),
      studentNo: _trimOrNull(_studentNoController),
      birthday: _trimOrNull(_birthdayController),
      parentName: _trimOrNull(_parentNameController),
      address: _trimOrNull(_addressController),
      homePhone: _trimOrNull(_homePhoneController),
      hobbies: _trimOrNull(_hobbiesController),
      health: _trimOrNull(_healthController),
      emergencyContact: _trimOrNull(_emergencyContactController),
      description: _trimOrNull(_descriptionController),
    );

    try {
      if (widget.student == null) {
        await ref.read(studentListProvider(widget.classId).notifier).addStudent(student);
      } else {
        await ref.read(studentListProvider(widget.classId).notifier).updateStudent(
              widget.student!.id,
              student.toJson(),
            );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败：$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.student == null ? '添加学生' : '编辑学生'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.pagePadding),
              children: [
                // ── Required fields ──
                Text('基本信息',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    )),
                const SizedBox(height: AppSpacing.gap3),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '姓名 *',
                    prefixIcon: Icon(Icons.person_rounded),
                  ),
                  validator: (value) => value?.trim().isEmpty == true ? '请输入姓名' : null,
                ),
                const SizedBox(height: AppSpacing.gap3),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _gender,
                        decoration: const InputDecoration(
                          labelText: '性别 *',
                          prefixIcon: Icon(Icons.wc_rounded),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'male', child: Text('男')),
                          DropdownMenuItem(value: 'female', child: Text('女')),
                        ],
                        onChanged: (value) => setState(() => _gender = value!),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.gap3),
                    Expanded(
                      child: TextFormField(
                        controller: _studentNoController,
                        decoration: const InputDecoration(
                          labelText: '学号',
                          prefixIcon: Icon(Icons.badge_rounded),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.gap5),

                // ── Contact info ──
                ExpansionTile(
                  title: const Text('联系方式'),
                  leading: Icon(Icons.phone_rounded, color: scheme.primary, size: 20),
                  initiallyExpanded: widget.student != null,
                  childrenPadding: const EdgeInsets.only(bottom: AppSpacing.gap3),
                  children: [
                    const SizedBox(height: AppSpacing.gap2),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(labelText: '学生电话'),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: AppSpacing.gap3),
                    TextFormField(
                      controller: _parentPhoneController,
                      decoration: const InputDecoration(labelText: '家长电话'),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: AppSpacing.gap3),
                    TextFormField(
                      controller: _homePhoneController,
                      decoration: const InputDecoration(labelText: '家庭电话'),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: AppSpacing.gap3),
                    TextFormField(
                      controller: _emergencyContactController,
                      decoration: const InputDecoration(labelText: '紧急联系人'),
                    ),
                  ],
                ),

                // ── Family & personal ──
                ExpansionTile(
                  title: const Text('家庭与个人'),
                  leading: Icon(Icons.family_restroom_rounded, color: scheme.primary, size: 20),
                  childrenPadding: const EdgeInsets.only(bottom: AppSpacing.gap3),
                  children: [
                    const SizedBox(height: AppSpacing.gap2),
                    TextFormField(
                      controller: _parentNameController,
                      decoration: const InputDecoration(labelText: '家长姓名'),
                    ),
                    const SizedBox(height: AppSpacing.gap3),
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(labelText: '家庭住址'),
                    ),
                    const SizedBox(height: AppSpacing.gap3),
                    TextFormField(
                      controller: _birthdayController,
                      decoration: const InputDecoration(
                        labelText: '生日 (YYYY-MM-DD)',
                        prefixIcon: Icon(Icons.cake_rounded),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.gap3),
                    TextFormField(
                      controller: _hobbiesController,
                      decoration: const InputDecoration(labelText: '兴趣爱好'),
                    ),
                    const SizedBox(height: AppSpacing.gap3),
                    TextFormField(
                      controller: _healthController,
                      decoration: const InputDecoration(labelText: '健康状况'),
                    ),
                  ],
                ),

                // ── Description & remarks ──
                ExpansionTile(
                  title: const Text('备注与描述'),
                  leading: Icon(Icons.description_rounded, color: scheme.primary, size: 20),
                  childrenPadding: const EdgeInsets.only(bottom: AppSpacing.gap3),
                  children: [
                    const SizedBox(height: AppSpacing.gap2),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(labelText: '学生描述'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: AppSpacing.gap3),
                    TextFormField(
                      controller: _remarksController,
                      decoration: const InputDecoration(labelText: '备注'),
                      maxLines: 3,
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.gap5),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _submit,
                    child: Text(widget.student == null ? '添加学生' : '保存修改'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
