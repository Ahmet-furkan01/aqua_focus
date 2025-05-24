import 'package:flutter/material.dart';

class CreateTaskDialog extends StatefulWidget {
  final Function(String description, String category) onTaskCreated;

  const CreateTaskDialog({
    super.key,
    required this.onTaskCreated,
  });

  @override
  State<CreateTaskDialog> createState() => _CreateTaskDialogState();
}

class _CreateTaskDialogState extends State<CreateTaskDialog> {
  final _descriptionController = TextEditingController();
  String _selectedCategory = 'Daily';
  bool _showReminder = false;
  String _priority = 'Normal';
  final List<String> _tags = [];

  final List<String> _categories = [
    'Daily',
    'Weekly',
    'Monthly',
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF02162D),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF5ECEDB).withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF5ECEDB).withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Create a Task & Routine',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _descriptionController,
              hint: 'Description',
              maxLines: 3,
            ),
            const SizedBox(height: 15),
            _buildCategorySelector(),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (_descriptionController.text.isNotEmpty) {
                      widget.onTaskCreated(
                        _descriptionController.text,
                        _selectedCategory,
                      );
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5ECEDB),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    'Create Task',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(15),
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        title: Text(
          'Choose Category',
          style: TextStyle(color: Colors.white.withOpacity(0.9)),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _selectedCategory,
              style: const TextStyle(color: Color(0xFF5ECEDB)),
            ),
            const Icon(Icons.arrow_forward_ios,
                color: Colors.white54, size: 16),
          ],
        ),
        onTap: _showCategoryPicker,
      ),
    );
  }

  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF02162D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _categories
              .map((category) => ListTile(
                    title: Text(
                      category,
                      style: const TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      setState(() => _selectedCategory = category);
                      Navigator.pop(context);
                    },
                    trailing: _selectedCategory == category
                        ? const Icon(Icons.check, color: Color(0xFF5ECEDB))
                        : null,
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildReminderToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: SwitchListTile(
        title: Text(
          'Add a Reminder',
          style: TextStyle(color: Colors.white.withOpacity(0.9)),
        ),
        value: _showReminder,
        onChanged: (value) => setState(() => _showReminder = value),
        activeColor: const Color(0xFF5ECEDB),
      ),
    );
  }

  Widget _buildPrioritySelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        title: Text(
          'Priority',
          style: TextStyle(color: Colors.white.withOpacity(0.9)),
        ),
        trailing: DropdownButton<String>(
          value: _priority,
          dropdownColor: const Color(0xFF02162D),
          style: const TextStyle(color: Color(0xFF5ECEDB)),
          underline: Container(),
          items: ['Low', 'Normal', 'High'].map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: (newValue) {
            if (newValue != null) {
              setState(() => _priority = newValue);
            }
          },
        ),
      ),
    );
  }

  Widget _buildTagsInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        title: Text(
          'Add Tags',
          style: TextStyle(color: Colors.white.withOpacity(0.9)),
        ),
        trailing: const Icon(Icons.add, color: Colors.white54),
        onTap: () {
          // TODO: Implement tag addition
        },
      ),
    );
  }
}
