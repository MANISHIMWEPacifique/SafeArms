// Side Menu Widget
// Navigation sidebar component

import 'package:flutter/material.dart';

class NavItem {
  final IconData icon;
  final String label;

  const NavItem({required this.icon, required this.label});
}

class SideMenuWidget extends StatelessWidget {
  final List<NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final String title;
  final String? subtitle;
  final VoidCallback? onLogout;

  const SideMenuWidget({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onItemSelected,
    this.title = 'SafeArms',
    this.subtitle,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: Color(0xFF252A3A),
        border: Border(right: BorderSide(color: Color(0xFF37404F), width: 1)),
      ),
      child: Column(
        children: [
          // Logo / Title
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFF37404F), width: 1),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined,
                    color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: Color(0xFF78909C),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Navigation items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = index == selectedIndex;
                return _buildNavItem(
                    item, isSelected, () => onItemSelected(index));
              },
            ),
          ),
          // Logout button
          if (onLogout != null)
            Container(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFF37404F), width: 1),
                ),
              ),
              child: ListTile(
                leading: const Icon(
                  Icons.logout,
                  color: Color(0xFFE85C5C),
                  size: 20,
                ),
                title: const Text(
                  'Logout',
                  style: TextStyle(color: Color(0xFFE85C5C), fontSize: 14),
                ),
                onTap: onLogout,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNavItem(NavItem item, bool isSelected, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF1E88E5).withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isSelected
            ? Border.all(color: const Color(0xFF1E88E5).withValues(alpha: 0.3))
            : null,
      ),
      child: ListTile(
        leading: Icon(
          item.icon,
          color: isSelected ? const Color(0xFF1E88E5) : const Color(0xFF78909C),
          size: 20,
        ),
        title: Text(
          item.label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFFB0BEC5),
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        dense: true,
        onTap: onTap,
      ),
    );
  }
}
