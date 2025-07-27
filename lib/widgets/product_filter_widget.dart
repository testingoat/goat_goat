import 'package:flutter/material.dart';

class ProductFilter {
  final String sortBy;
  final bool ascending;
  final String searchQuery;
  final String? approvalStatus;
  final bool? isActive;

  ProductFilter({
    this.sortBy = 'created_at',
    this.ascending = false,
    this.searchQuery = '',
    this.approvalStatus,
    this.isActive,
  });

  ProductFilter copyWith({
    String? sortBy,
    bool? ascending,
    String? searchQuery,
    String? approvalStatus,
    bool? isActive,
  }) {
    return ProductFilter(
      sortBy: sortBy ?? this.sortBy,
      ascending: ascending ?? this.ascending,
      searchQuery: searchQuery ?? this.searchQuery,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      isActive: isActive ?? this.isActive,
    );
  }
}

class ProductFilterWidget extends StatefulWidget {
  final Function(ProductFilter) onFilterChanged;
  final ProductFilter currentFilter;
  
  const ProductFilterWidget({
    super.key,
    required this.onFilterChanged,
    required this.currentFilter,
  });

  @override
  State<ProductFilterWidget> createState() => _ProductFilterWidgetState();
}

class _ProductFilterWidgetState extends State<ProductFilterWidget> {
  late TextEditingController _searchController;
  late ProductFilter _currentFilter;

  @override
  void initState() {
    super.initState();
    _currentFilter = widget.currentFilter;
    _searchController = TextEditingController(text: _currentFilter.searchQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _updateFilter({
    String? sortBy,
    bool? ascending,
    String? searchQuery,
    String? approvalStatus,
    bool? isActive,
  }) {
    setState(() {
      _currentFilter = _currentFilter.copyWith(
        sortBy: sortBy,
        ascending: ascending,
        searchQuery: searchQuery,
        approvalStatus: approvalStatus,
        isActive: isActive,
      );
    });
    widget.onFilterChanged(_currentFilter);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        title: const Row(
          children: [
            Icon(Icons.filter_list, color: Color(0xFF059669)),
            SizedBox(width: 8),
            Text(
              'Filters & Sort',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF059669),
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Search products',
                    hintText: 'Enter product name...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _updateFilter(searchQuery: '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF059669)),
                    ),
                  ),
                  onChanged: (value) {
                    _updateFilter(searchQuery: value);
                  },
                ),
                const SizedBox(height: 16),
                
                // Sort options
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Sort by',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _currentFilter.sortBy,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFF059669)),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'created_at',
                                child: Text('Date Created'),
                              ),
                              DropdownMenuItem(
                                value: 'name',
                                child: Text('Product Name'),
                              ),
                              DropdownMenuItem(
                                value: 'price',
                                child: Text('Price'),
                              ),
                              DropdownMenuItem(
                                value: 'updated_at',
                                child: Text('Last Updated'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                _updateFilter(sortBy: value);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Order',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: () => _updateFilter(ascending: false),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(8),
                                  bottomLeft: Radius.circular(8),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: !_currentFilter.ascending
                                        ? const Color(0xFF059669)
                                        : Colors.transparent,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(8),
                                      bottomLeft: Radius.circular(8),
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.arrow_downward,
                                    size: 16,
                                    color: !_currentFilter.ascending
                                        ? Colors.white
                                        : Colors.grey[600],
                                  ),
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: Colors.grey[300],
                              ),
                              InkWell(
                                onTap: () => _updateFilter(ascending: true),
                                borderRadius: const BorderRadius.only(
                                  topRight: Radius.circular(8),
                                  bottomRight: Radius.circular(8),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _currentFilter.ascending
                                        ? const Color(0xFF059669)
                                        : Colors.transparent,
                                    borderRadius: const BorderRadius.only(
                                      topRight: Radius.circular(8),
                                      bottomRight: Radius.circular(8),
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.arrow_upward,
                                    size: 16,
                                    color: _currentFilter.ascending
                                        ? Colors.white
                                        : Colors.grey[600],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
