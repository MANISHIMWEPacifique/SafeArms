import sys
import re

file_path = r'c:\dev\SafeArms\frontend\lib\screens\workflows\station_custody_management_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

new_method = """  Widget _buildFilterBar(CustodyProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF252A3A),
        border: Border.all(color: const Color(0xFF37404F)),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isNarrow = constraints.maxWidth < 600;
          
          final statusFilter = _buildFilterDropdown(
            label: 'Status',
            value: provider.statusFilter,
            items: const [
              {'value': 'active', 'label': 'Active'},
              {'value': 'all', 'label': 'All'},
              {'value': 'returned', 'label': 'Returned'},
            ],
            onChanged: (value) => provider.setStatusFilter(value ?? 'active'),
          );

          final typeFilter = _buildFilterDropdown(
            label: 'Custody Type',
            value: provider.typeFilter,
            items: const [
              {'value': 'all', 'label': 'All Types'},
              {'value': 'permanent', 'label': 'Permanent'},
              {'value': 'temporary', 'label': 'Temporary'},
              {'value': 'personal_long_term', 'label': 'Personal Long-term'},
            ],
            onChanged: (value) => provider.setTypeFilter(value ?? 'all'),
          );

          final searchWidget = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Search',
                  style: TextStyle(color: Color(0xFFB0BEC5), fontSize: 13)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2A3040),
                  border: Border.all(color: const Color(0xFF37404F)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => provider.setSearchQuery(value),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Search by officer or serial number',
                    hintStyle:
                        TextStyle(color: Color(0xFF78909C), fontSize: 14),
                    prefixIcon: Icon(Icons.search,
                        color: Color(0xFF78909C), size: 20),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: statusFilter),
                    const SizedBox(width: 16),
                    Expanded(child: typeFilter),
                  ],
                ),
                const SizedBox(height: 16),
                searchWidget,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: statusFilter),
              const SizedBox(width: 16),
              Expanded(child: typeFilter),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: searchWidget),
            ],
          );
        },
      ),
    );
  }"""

pattern = r"  Widget _buildFilterBar\(CustodyProvider provider\) \{.*?(?=  Widget _buildFilterDropdown)"

new_content = re.sub(pattern, new_method + "\n\n", content, flags=re.DOTALL)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(new_content)

print(f"Updated {file_path}")
