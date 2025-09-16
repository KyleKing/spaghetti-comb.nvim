# Implementation Plan

- [ ] 0. Archive v1 code and migrate useful components
  - [ ] 0.1 Analyze spaghetti-comb-v1 codebase for reusable components
    - Review coupling/graph.lua for relationship analysis algorithms
    - Review persistence/storage.lua for data persistence patterns
    - Review ui/relations.lua for split window management
    - Review analyzer.lua for LSP integration patterns
    - Identify components that can be migrated to v2 structure
  - [ ] 0.2 Create archive directory for v1 code
    - Move non-reusable v1 code to archive/spaghetti-comb-v1/
    - Preserve v1 code for reference but remove from active development
    - Update any references to archived v1 components
  - [ ] 0.3 Migrate useful v1 components to v2
    - Migrate proven algorithms from v1 coupling analysis
    - Adapt v1 persistence patterns for v2 storage system
    - Reuse v1 UI patterns for v2 relations panel
    - Integrate v1 LSP hooks into v2 navigation system
  - [ ] 0.4 Update documentation references
    - Update README.md to reflect v2 architecture
    - Update any v1-specific documentation
    - Ensure CLAUDE.md reflects current development state

- [x] 1. Set up project structure and core interfaces
  - Create v2 directory structure: history/, navigation/, ui/, utils/, tests/
  - Define enhanced data models in types.lua including RelationsData for code analysis
  - Create configuration schema with v2-specific settings for relations panel and coupling analysis
  - Set up modular plugin architecture with clear separation of concerns
  - _Requirements: All requirements - foundational v2 setup_

- [-] 2. Implement core history manager with intelligent pruning
  - [ ] 2.1 Create enhanced history tracking functionality
    - Write history manager module with entry recording and retrieval
    - Implement navigation trail data structure with current index tracking
    - Create unique ID generation for navigation entries
    - Add exploration state detection based on time between jumps
    - Integrate with v2 relations panel for real-time updates
    - _Requirements: 1.1, 1.2, 1.3, 12.3_
  
  - [ ] 2.2 Add project-aware history separation
    - Implement project root detection using git/workspace markers
    - Create separate history contexts per project
    - Write project switching logic that maintains separate trails
    - _Requirements: 7.1, 7.3_
  
  - [ ] 2.3 Implement intelligent pruning with location recovery
    - Write debounced pruning system with 2-minute delay
    - Create location recovery algorithm for shifted line numbers
    - Implement marking of unrecoverable locations as inactive
    - Add preservation of original line numbers for user reference
    - Write time-based pruning for entries older than configurable limit
    - Create inconsequential jump detection and removal within same file
    - _Requirements: 1.4, 1.5, 1.6, 1.7, 1.8, 1.9_

- [ ] 3. Build relations panel UI system
  - [ ] 3.1 Implement split window relations panel
    - Create relations.lua module for split window management
    - Implement focus mode with side-by-side preview
    - Add window positioning and sizing logic
    - Integrate with existing navigation system
    - _Requirements: 3.6, 3.7, 4.1, 4.2, 4.3, 4.4, 4.5_
  
  - [ ] 3.2 Integrate with built-in jumplist functionality
    - Extend Ctrl-O and Ctrl-I commands to work with breadcrumb history
    - Create enhanced navigation commands that complement existing jumplist
    - Ensure compatibility with Neovim's built-in jump tracking
    - _Requirements: 6.1, 6.3_

- [ ] 4. Implement LSP integration for code analysis
  - [ ] 4.1 Create LSP event hooks for code relationships
    - Hook into LSP go-to-definition events to record navigation jumps
    - Implement reference finding integration that populates relations panel
    - Create implementation jump tracking for LSP-based navigation
    - Add call hierarchy analysis for comprehensive relationship mapping
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 6.2_
  
  - [ ] 4.2 Add enhanced LSP commands with graceful fallback
    - Write enhanced go-to-definition that extends built-in LSP functionality
    - Create reference navigation with breadcrumb integration
    - Implement graceful degradation when LSP is unavailable
    - _Requirements: 2.4, 6.2_

- [ ] 5. Build coupling analysis and bookmark system
  - [ ] 5.1 Implement coupling analysis metrics
    - Create coupling calculation algorithms for code relationships
    - Implement dependency analysis and relationship strength metrics
    - Add visual indicators for coupling intensity in relations panel
    - Integrate coupling analysis with navigation decisions
    - _Requirements: 13.1, 13.2, 13.3, 13.4, 13.5_
  - [ ] 5.2 Implement manual bookmark functionality
    - Create bookmark toggle command for current cursor position
    - Write bookmark storage and retrieval with persistence support
    - Implement bookmark removal and clearing commands
    - _Requirements: 10.2, 10.5_
  
  - [ ] 5.2 Add automatic frequent location detection
    - Implement visit count tracking for navigation entries
    - Create automatic frequent location marking based on visit threshold
    - Write frequent location management and cleanup
    - _Requirements: 10.1, 10.3_

- [ ] 6. Create relations panel display system
  - [ ] 6.1 Implement relations panel display logic
    - Write relations panel display with toggle functionality
    - Create visual styling for code relationships and coupling metrics
    - Implement panel positioning and layout management
    - Add filtering and sorting capabilities for relations data
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_
  
  - [ ] 6.2 Add collapsible breadcrumb interface
    - Implement mini.files-like collapse behavior for unfocused items
    - Create focus management that expands selected item and immediate neighbors
    - Write state management for breadcrumb focus and collapse states
    - _Requirements: 4.3, 4.4_
  
  - [ ] 6.3 Create visual distinction for entry types
    - Implement different visual styling for bookmarked locations
    - Add visual indicators for frequent locations
    - Create branch point visualization in breadcrumb trail
    - Show original vs current line numbers for recovered locations
    - _Requirements: 1.3, 1.9, 10.3_

- [ ] 7. Build floating tree window for navigation visualization
  - [ ] 7.1 Create unicode tree rendering system
    - Write unicode box-drawing character tree renderer for navigation branches
    - Implement branch sorting by most to least recent
    - Create visual marking for bookmarked and frequent locations
    - Add subtle color scheme for improved readability
    - Integrate with relations panel for comprehensive navigation view
    - _Requirements: 3.6, 3.7, 3.8, 3.9_
  
  - [ ] 7.2 Add floating window management
    - Create floating window with left tree panel and right preview panel
    - Implement vim motion support for tree navigation
    - Write window positioning and sizing logic
    - Add window show/hide/toggle functionality
    - _Requirements: 3.6, 3.7_
  
  - [ ] 7.3 Implement tree preview pane
    - Create code context extraction for selected tree nodes
    - Write preview window management with proper positioning
    - Implement syntax highlighting for preview content
    - Add real-time preview updates based on tree selection
    - _Requirements: 9.1, 9.2, 9.3, 9.4_

- [ ] 8. Implement dual-mode picker system
  - [ ] 8.1 Create bookmark management picker mode
    - Write bookmark picker with fuzzy filtering by filename and code content
    - Implement bookmark toggle functionality within picker
    - Create frecency-based sorting for bookmark management
    - Add preview support for bookmark entries
    - Integrate with relations panel for enhanced bookmark context
    - _Requirements: 3.8, 10.4_
  
  - [ ] 8.2 Create navigation picker mode
    - Write navigation history picker with same filtering capabilities
    - Implement recency-based sorting for quick navigation
    - Create mode switching between bookmark and navigation modes
    - Add jump-to-location functionality from picker
    - _Requirements: 3.9_
  
  - [ ] 8.3 Add fallback picker functionality
    - Implement graceful fallback when mini.pick is not installed
    - Create basic selection interface using Neovim's built-in functionality
    - Write feature detection and conditional picker loading
    - _Requirements: 3.5_

- [ ] 9. Add debug logging and error handling
  - [ ] 9.1 Implement debug logging system
    - Create configurable debug logging following Neovim standards
    - Write log level management (debug, info, warn, error)
    - Implement state inspection commands for debugging
    - _Requirements: 11.1, 11.3, 11.5_
  
  - [ ] 9.2 Add comprehensive error handling
    - Implement graceful degradation for file system errors
    - Create error handling for LSP unavailability
    - Write memory pressure and performance error handling
    - _Requirements: 11.2, 11.4_

- [ ] 10. Create statusline integration
  - [ ] 10.1 Implement branch status display
    - Write statusline component for active exploration state
    - Create minimal display format with branch ID, depth, and necessary info
    - Implement idle branching indicator for non-exploration states
    - Add exploration state detection based on jump timing
    - _Requirements: 12.1, 12.2, 12.3, 12.4_
  
  - [ ] 10.2 Add statusline integration
    - Create statusline component registration
    - Implement minimal display string generation
    - Write statusline update triggers based on navigation events
    - Add configuration option to enable/disable statusline display
    - _Requirements: 12.1, 12.2, 12.4_

- [ ] 11. Create configuration and command interface
  - [ ] 11.1 Implement configuration management
    - Write configuration validation with sensible defaults including visual settings
    - Create configuration loading and updating functionality
    - Implement per-project configuration override support
    - Add pruning debounce and exploration timeout settings
    - _Requirements: All requirements - configuration foundation_
  
  - [ ] 11.2 Add user commands and keybindings
    - Create navigation commands (go_back, go_forward, jump_to_history)
    - Implement bookmark management commands
    - Write history management commands (clear, clear_project)
    - Add hotkey for breadcrumb display and floating tree window
    - _Requirements: 3.1, 3.2, 3.3, 4.2, 7.4, 10.5_

- [ ] 12. Implement optional persistence
  - [ ] 12.1 Add history persistence functionality
    - Create optional history saving on exit with recovery information
    - Implement history restoration on project reopening
    - Write persistence cleanup and management
    - Add persistence of original vs recovered line number information
    - _Requirements: 7.2_
  
  - [ ] 12.2 Add bookmark persistence
    - Implement bookmark saving and restoration
    - Create bookmark file management per project
    - Write bookmark cleanup for deleted/moved files
    - _Requirements: 10.5_

- [ ] 13. Write comprehensive test suite using mini.test
  - [ ] 13.1 Create core functionality tests
    - Write tests for navigation history recording and retrieval
    - Create tests for branch creation and management
    - Implement tests for intelligent pruning with location recovery
    - Add tests for debounced pruning system
    - Test exploration state detection algorithm
    - _Requirements: 8.1, 8.2, 8.3_
  
  - [ ] 13.2 Add integration tests
    - Write tests for LSP integration extending built-in functionality
    - Create tests for jumplist enhancement
    - Implement tests for project-aware history separation
    - Add tests for statusline integration
    - _Requirements: 8.1, 8.2, 8.3_
  
  - [ ] 13.3 Create UI and visual tests
    - Write tests for hotkey-triggered breadcrumb display
    - Create tests for collapsible breadcrumb interface
    - Implement tests for unicode tree rendering
    - Add tests for floating window management
    - Test dual-mode picker functionality
    - _Requirements: 8.1, 8.2, 8.3_
  
  - [ ] 13.4 Add performance and bookmark tests
    - Write performance tests for navigation operations (<50ms)
    - Create tests for memory usage under large history loads
    - Implement tests for bookmark functionality (manual and automatic)
    - Add tests for location recovery performance
    - Test pruning debounce effectiveness
    - _Requirements: 8.1, 8.2, 8.3_

- [ ] 14. Performance optimization and final integration
  - [ ] 14.1 Optimize performance for large histories
    - Implement efficient data structures for history storage with recovery metadata
    - Create lazy loading for preview content and unicode tree rendering
    - Write memory usage optimization and monitoring
    - Optimize debounced pruning performance
    - _Requirements: 5.1, 5.2, 5.3, 5.4_
  
  - [ ] 14.2 Final integration and polish
    - Create comprehensive plugin initialization and setup
    - Implement all user commands and autocommands including hotkeys
    - Write final integration tests for complete user workflows
    - Add documentation for unicode tree visualization and dual-mode picker
    - _Requirements: All requirements - final integration_