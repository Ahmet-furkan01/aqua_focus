import 'package:flutter/material.dart';
import '../widgets/ocean_background.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/create_task_dialog.dart';
import '../services/api_service.dart';

class TasksScreen extends StatefulWidget {
  final String? userId;

  const TasksScreen({
    super.key,
    this.userId,
  });

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final Map<String, bool> _completedTasks = {};
  final Map<String, List<Task>> _tasksByCategory = {
    'daily': [],
    'weekly': [],
    'monthly': [],
  };
  final int _selectedIndex = 1;
  late String? userId;
  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    userId = widget.userId;
    _fetchAndSetTasks();
  }

  Future<void> _fetchAndSetTasks() async {
    if (userId == null) {
      print('User ID is null, cannot fetch tasks');
      return;
    }
    setState(() => _isLoading = true);
    try {
      print('Fetching tasks for user: $userId');
      final tasks = await _apiService.getUserTasks(userId!);
      print('Fetched tasks: $tasks');

      _tasksByCategory.forEach((key, value) => value.clear());
      _completedTasks.clear();

      for (var task in tasks) {
        final cat = (task['task_type'] as String).toLowerCase();
        print('Processing task: $task, category: $cat');
        if (_tasksByCategory.containsKey(cat)) {
          final isCompleted = (task['status'] ?? '') == 'completed';
          final t = Task(
            task['task_id'],
            task['description'] ?? '',
            '',
            icon: Icons.task_alt,
          );
          _tasksByCategory[cat]!.add(t);
          _completedTasks[task['task_id']] = isCompleted;
          print('Added task to category $cat: ${t.description}');
        }
      }
      print('Final task categories: $_tasksByCategory');
    } catch (e) {
      print('Error fetching tasks: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Görevler alınamadı: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
    setState(() => _isLoading = false);
  }

  void _toggleTask(String taskId) async {
    if (userId == null) return;
    final isCompleted = _completedTasks[taskId] ?? false;
    setState(() {
      _completedTasks[taskId] = !isCompleted;
    });
    try {
      if (!isCompleted) {
        await _apiService.completeUserTask(userId: userId!, taskId: taskId);
      } else {
        await _apiService.uncompleteUserTask(userId: userId!, taskId: taskId);
      }
      await _fetchAndSetTasks();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Görev güncellenemedi: $e')),
      );
    }
  }

  void _showCreateTaskDialog() {
    showDialog(
      context: context,
      builder: (context) => CreateTaskDialog(
        onTaskCreated: (description, category) async {
          if (userId == null) return;
          try {
            final result = await _apiService.createUserTask(
              userId: userId!,
              description: description,
              taskType: category.toLowerCase(),
            );
            await _fetchAndSetTasks();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message'] ?? 'Task created successfully'),
                backgroundColor: Colors.green,
              ),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Görev eklenemedi: $e')),
            );
          }
        },
      ),
    );
  }

  Future<bool> _deleteTask(String taskId) async {
    if (userId == null) return false;
    try {
      await _apiService.deleteUserTask(userId: userId!, taskId: taskId);
      await _fetchAndSetTasks();
      return true;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Görev silinemedi: $e')),
      );
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: OceanBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios),
                      color: Colors.white,
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text(
                      'Tasks',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.add),
                      color: Colors.white,
                      onPressed: _showCreateTaskDialog,
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF5ECEDB),
                        padding: const EdgeInsets.all(12),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    ..._tasksByCategory.entries
                        .map((entry) => _buildTaskCategory(
                              entry.key,
                              entry.value,
                              taskCount: entry.value.length,
                              expanded: entry.value.isEmpty,
                            )),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
              const BottomNavBar(
                selectedIndex: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskCategory(String title, List<Task> tasks,
      {int? taskCount, bool expanded = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Theme(
        data: ThemeData(
          dividerColor: Colors.transparent,
          checkboxTheme: CheckboxThemeData(
            fillColor: MaterialStateProperty.resolveWith<Color>((states) {
              if (states.contains(MaterialState.selected)) {
                return const Color(0xFF5ECEDB);
              }
              return Colors.white.withOpacity(0.3);
            }),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        child: ExpansionTile(
          title: Text(
            title[0].toUpperCase() + title.substring(1),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (taskCount != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    taskCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Icon(
                expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: Colors.white.withOpacity(0.7),
              ),
            ],
          ),
          initiallyExpanded: true,
          children: tasks.map((task) => _buildTaskItem(task)).toList(),
        ),
      ),
    );
  }

  Widget _buildTaskItem(Task task) {
    final isCompleted = _completedTasks[task.id] ?? false;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: isCompleted,
            onChanged: (bool? value) => _toggleTask(task.id),
          ),
          const SizedBox(width: 8),
          Icon(
            task.icon,
            color: Colors.white.withOpacity(0.7),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.description,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (task.subtitle.isNotEmpty)
                  Text(
                    task.subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                      decoration:
                          isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            color: Colors.white.withOpacity(0.7),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Görevi Sil'),
                  content:
                      const Text('Are you sure you want to delete this task?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        final success = await _deleteTask(task.id);
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Task deleted successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class Task {
  final String id;
  final String description;
  final String subtitle;
  final IconData icon;

  Task(this.id, this.description, this.subtitle, {required this.icon});
}
