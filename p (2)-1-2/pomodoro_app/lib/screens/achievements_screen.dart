import 'package:flutter/material.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Örnek veriler - gerçek uygulamada backend'den gelecek
  final List<MarineCreature> _unlockedCreatures = [
    MarineCreature(
      name: 'Clownfish',
      description: 'The first friendly fish to join your reef!',
      icon: 'assets/icons/clown-fish.png',
      rarity: 'Common',
      color: Colors.orangeAccent,
      isUnlocked: true,
      unlockedBy: 'Complete 1 Pomodoro Session',
    ),
    MarineCreature(
      name: 'Coral Branch',
      description: 'Foundation of your reef ecosystem',
      icon: 'assets/icons/coral.png',
      rarity: 'Common',
      color: Colors.pinkAccent,
      isUnlocked: true,
      unlockedBy: 'Complete 2 Pomodoro Sessions',
    ),
    MarineCreature(
      name: 'Sea Anemone',
      description: 'A living home for small fish',
      icon: 'assets/icons/anemone.png',
      rarity: 'Uncommon',
      color: Colors.purpleAccent,
      isUnlocked: true,
      unlockedBy: 'Complete 5 Pomodoro Sessions',
    ),
  ];

  final List<MarineCreature> _lockedCreatures = [
    MarineCreature(
      name: 'Octopus',
      description: 'An intelligent creature with eight limbs',
      icon: 'assets/icons/octopus.png',
      rarity: 'Rare',
      color: Colors.indigoAccent,
      isUnlocked: false,
      unlockedBy: 'Complete 10 Pomodoro Sessions',
    ),
    MarineCreature(
      name: 'Seahorse',
      description: 'A graceful swimmer that brings luck',
      icon: 'assets/icons/seahorse.png',
      rarity: 'Rare',
      color: Colors.tealAccent,
      isUnlocked: false,
      unlockedBy: 'Complete a 5-day streak',
    ),
    MarineCreature(
      name: 'Whale Shark',
      description: 'The gentle giant of your ecosystem',
      icon: 'assets/icons/whale.png',
      rarity: 'Legendary',
      color: Colors.blueAccent,
      isUnlocked: false,
      unlockedBy: 'Complete 50 Pomodoro Sessions',
    ),
  ];

  final List<Achievement> _achievements = [
    Achievement(
      title: 'First Focus',
      description: 'Complete your first Pomodoro session',
      isUnlocked: true,
      icon: Icons.play_circle_filled,
      color: Colors.greenAccent,
      progress: 1.0,
    ),
    Achievement(
      title: 'Focus Streak',
      description: 'Complete 3 Pomodoro sessions in a row',
      isUnlocked: true,
      icon: Icons.local_fire_department,
      color: Colors.orangeAccent,
      progress: 1.0,
    ),
    Achievement(
      title: 'Deep Worker',
      description: 'Complete 10 Pomodoro sessions',
      isUnlocked: false,
      icon: Icons.work,
      color: Colors.blueAccent,
      progress: 0.5,
    ),
    Achievement(
      title: 'Ecosystem Builder',
      description: 'Unlock 10 marine creatures',
      isUnlocked: false,
      icon: Icons.eco,
      color: Colors.tealAccent,
      progress: 0.3,
    ),
    Achievement(
      title: 'Marine Biologist',
      description: 'Collect all common and uncommon creatures',
      isUnlocked: false,
      icon: Icons.science,
      color: Colors.purpleAccent,
      progress: 0.2,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF1B4B6C),
              const Color(0xFF0A2A3F),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRewardsTab(),
                    _buildAchievementsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Colors.white,
              size: 22,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Achievements & Rewards',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.emoji_events,
                  color: Colors.amberAccent,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  '${_achievements.where((a) => a.isUnlocked).length}/${_achievements.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(25),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          color: const Color(0xFF64C8FF),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF64C8FF).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withOpacity(0.6),
        labelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: 16,
        ),
        tabs: const [
          Tab(
            text: 'Marine Collection',
            icon: Icon(Icons.pets),
          ),
          Tab(
            text: 'Achievements',
            icon: Icon(Icons.emoji_events),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardsTab() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: Color(0xFF64C8FF),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Unlocked (${_unlockedCreatures.length})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildCreatureGrid(_unlockedCreatures, true),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(
                  Icons.lock_outline,
                  color: Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Locked (${_lockedCreatures.length})',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildCreatureGrid(_lockedCreatures, false),
        ],
      ),
    );
  }

  Widget _buildCreatureGrid(List<MarineCreature> creatures, bool unlocked) {
    return Expanded(
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.85,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: creatures.length,
        itemBuilder: (context, index) {
          final creature = creatures[index];
          return _buildCreatureCard(creature, unlocked);
        },
      ),
    );
  }

  Widget _buildCreatureCard(MarineCreature creature, bool unlocked) {
    return GestureDetector(
      onTap: () => _showCreatureDetails(creature),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black38,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: unlocked
                ? creature.color.withOpacity(0.7)
                : Colors.grey.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: unlocked
              ? [
                  BoxShadow(
                    color: creature.color.withOpacity(0.2),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: unlocked
                    ? creature.color.withOpacity(0.15)
                    : Colors.grey.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Image.asset(
                creature.icon,
                width: 40,
                height: 40,
                color: !unlocked ? Colors.grey : null, // Kilitliyse gri ton
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              unlocked ? creature.name : '???',
              style: TextStyle(
                color: unlocked ? Colors.white : Colors.grey,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: unlocked
                    ? _getRarityColor(creature.rarity).withOpacity(0.2)
                    : Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                unlocked ? creature.rarity : 'Locked',
                style: TextStyle(
                  color:
                      unlocked ? _getRarityColor(creature.rarity) : Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (!unlocked) ...[
              const SizedBox(height: 10),
              Text(
                creature.unlockedBy,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showCreatureDetails(MarineCreature creature) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0A2A3F),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: creature.color.withOpacity(0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 15,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: creature.color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Image.asset(
                  creature.icon,
                  width: 60,
                  height: 60,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                creature.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getRarityColor(creature.rarity).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  creature.rarity,
                  style: TextStyle(
                    color: _getRarityColor(creature.rarity),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                creature.description,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.emoji_events,
                    color: creature.color,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Unlocked by: ${creature.unlockedBy}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: creature.color,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAchievementsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _achievements.length,
      itemBuilder: (context, index) {
        final achievement = _achievements[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.black38,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: achievement.isUnlocked
                  ? achievement.color.withOpacity(0.5)
                  : Colors.grey.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: achievement.isUnlocked
                ? [
                    BoxShadow(
                      color: achievement.color.withOpacity(0.2),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: achievement.isUnlocked
                        ? achievement.color.withOpacity(0.15)
                        : Colors.grey.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    achievement.icon,
                    color: achievement.isUnlocked
                        ? achievement.color
                        : Colors.grey,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            achievement.title,
                            style: TextStyle(
                              color: achievement.isUnlocked
                                  ? Colors.white
                                  : Colors.grey,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (achievement.isUnlocked)
                            const Icon(
                              Icons.check_circle,
                              color: Colors.greenAccent,
                              size: 20,
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        achievement.description,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: achievement.progress,
                          backgroundColor: Colors.grey.withOpacity(0.3),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            achievement.isUnlocked
                                ? Colors.greenAccent
                                : achievement.color,
                          ),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${(achievement.progress * 100).toInt()}% completed',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1B4B6C).withOpacity(0.8),
            const Color(0xFF0A2A3F),
          ],
        ),
      ),
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: const Color(0xFF64C8FF).withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.home_outlined, 0),
            _buildNavItem(Icons.menu, 1),
            _buildNavItem(Icons.bolt_outlined, 2),
            _buildNavItem(Icons.bar_chart_outlined, 3),
            _buildNavItem(Icons.settings_outlined, 4),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index) {
    final isSelected = index == 3;
    return IconButton(
      icon: Icon(
        icon,
        color: isSelected
            ? const Color(0xFF64C8FF)
            : const Color(0xFFE6F3F5).withOpacity(0.5),
        size: 26,
      ),
      onPressed: () {
        switch (index) {
          case 0:
            Navigator.pushReplacementNamed(context, '/home');
            break;
          case 1:
            Navigator.pushReplacementNamed(context, '/tasks');
            break;
          case 2:
            Navigator.pushReplacementNamed(context, '/pomodoro');
            break;
          case 3:
            break;
          case 4:
            Navigator.pushReplacementNamed(context, '/settings');
            break;
        }
      },
    );
  }

  Color _getRarityColor(String rarity) {
    switch (rarity) {
      case 'Common':
        return Colors.greenAccent;
      case 'Uncommon':
        return Colors.blueAccent;
      case 'Rare':
        return Colors.purpleAccent;
      case 'Legendary':
        return Colors.orangeAccent;
      default:
        return Colors.grey;
    }
  }
}

class MarineCreature {
  final String name;
  final String description;
  final String icon;
  final String rarity;
  final Color color;
  final bool isUnlocked;
  final String unlockedBy;

  MarineCreature({
    required this.name,
    required this.description,
    required this.icon,
    required this.rarity,
    required this.color,
    required this.isUnlocked,
    required this.unlockedBy,
  });
}

class Achievement {
  final String title;
  final String description;
  final bool isUnlocked;
  final IconData icon;
  final Color color;
  final double progress;

  Achievement({
    required this.title,
    required this.description,
    required this.isUnlocked,
    required this.icon,
    required this.color,
    required this.progress,
  });
}
