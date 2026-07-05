import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../controllers/prompts_controller.dart';
import '../prompts_ai.dart';
import '../screens/prompts_home_page.dart';
import '../widgets/show_delete_note_dialog.dart';
import '../controllers/notes_controller.dart';
import '../theme/app_theme.dart';

class NotesHomePage extends StatefulWidget {
  const NotesHomePage({super.key});

  @override
  _NotesHomePageState createState() => _NotesHomePageState();
}

class _NotesHomePageState extends State<NotesHomePage> {
  final NotesController _notesController = NotesController();
  final PromptsController _promptsController = PromptsController();
  int _selectedNoteId = -1;
  int _currentPage = 1;
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _pageNumberController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int? _newNoteId;
  final TextEditingController _folderController = TextEditingController();
  double _folderListWidth = 200;
  double _notesListWidth = 300;
  bool _isFolderListVisible = true;
  static const double _minFolderListWidth = 170.0;
  static const double _maxFolderListWidth = 500.0;
  static const double _minNotesListWidth = 200.0;
  static const double _maxNotesListWidth = 600.0;
  List<TextEditingController> _pageControllers = [];
  List<FocusNode> _pageFocusNodes = [];
  final ScrollController _pageScrollController = ScrollController();
  bool _showAiPrompt = false;
  final TextEditingController _aiPromptController = TextEditingController();
  String? _favoritePromptTitle1;
  String? _favoritePromptTitle2;
  String? _favoritePromptTitle3;
  bool _isLoadingAiResponse = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_filterNotes);
    _noteController.addListener(_handleNoteInput);
    _pageControllers = [TextEditingController()];
    _pageFocusNodes = [FocusNode()];
    _pageControllers.first.addListener(_handleNoteInput);
    _pageScrollController.addListener(_updateCurrentPage);
    _pageNumberController.text = '1';
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterNotes);
    _noteController.removeListener(_handleNoteInput);
    _searchController.dispose();
    _noteController.dispose();
    _scrollController.dispose();
    _pageScrollController.dispose();
    _pageControllers.first.removeListener(_handleNoteInput);
    _pageNumberController.dispose();
    _pageScrollController.removeListener(_updateCurrentPage);
    _pageNumberController.dispose();
    _aiPromptController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await _notesController.loadFolders();
    await _notesController.loadNotes();
    if (_selectedNoteId != -1) {
      await _notesController.loadPages(_selectedNoteId);
      _loadPagesForNote(_selectedNoteId);
    }
    _getFavoritePromptTitle(1);
    _getFavoritePromptTitle(2);
    _getFavoritePromptTitle(3);
    setState(() {});
  }

  void _loadPagesForNote(int noteId) {
    _pageControllers.clear();
    _pageFocusNodes.clear();
    for (var page in _notesController.pages) {
      _pageControllers.add(TextEditingController(text: page.content));
      _pageFocusNodes.add(FocusNode());
    }
    if (_pageControllers.isEmpty) {
      _pageControllers.add(TextEditingController());
      _pageFocusNodes.add(FocusNode());
    }
  }

  void _addNewPage(int index) {
    setState(() {
      _pageControllers.add(TextEditingController());
      _pageFocusNodes.add(FocusNode());
    });
    _notesController.addPage(_selectedNoteId, '', pageIndex: index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pageScrollController.animateTo(
        _pageScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      _pageFocusNodes.last.requestFocus();
    });
  }

  void _updateFolderListWidth(double delta) {
    setState(() {
      _folderListWidth += delta;
      if (_folderListWidth < _minFolderListWidth) {
        _isFolderListVisible = false;
        _folderListWidth = 0;
      } else {
        _isFolderListVisible = true;
        _folderListWidth =
            _folderListWidth.clamp(_minFolderListWidth, _maxFolderListWidth);
      }
    });
  }

  void _showFolderContextMenu(
      BuildContext context, int folderId, String folderName, Offset position) {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          child: const ListTile(
            leading: Icon(Icons.edit),
            title: Text('Rename'),
          ),
          onTap: () => _renameFolder(folderId, folderName),
        ),
        PopupMenuItem(
          child: const ListTile(
            leading: Icon(Icons.delete),
            title: Text('Delete'),
          ),
          onTap: () => _showDeleteFolderDialog(),
        ),
      ],
    );
  }

  void _showNoteContextMenu(
      BuildContext context, int noteId, String noteTitle, Offset position) {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          child: const ListTile(
            leading: Icon(Icons.delete),
            title: Text('Delete'),
          ),
          onTap: () => _showDeleteNoteDialog(),
        ),
        PopupMenuItem(
          child: ListTile(
            leading:
                Image.asset('lib/icons/move_icon.png', width: 17, height: 17),
            title: const Text('Move to Folder'),
          ),
          onTap: () => _showMoveFolderDialog(noteId),
        ),
      ],
    );
  }

  void _renameFolder(int folderId, String currentName) {
    _folderController.text = currentName;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Folder'),
        content: TextField(
          autofocus: true,
          controller: _folderController,
          decoration: const InputDecoration(hintText: 'Enter new folder name'),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('Rename'),
            onPressed: () async {
              final newName = _folderController.text;
              if (newName.isNotEmpty) {
                await _notesController.renameFolder(folderId, newName);
                Navigator.of(context).pop();
                await _loadData();
              }
            },
          ),
        ],
      ),
    );
  }

  void _updateNotesListWidth(double delta) {
    setState(() {
      _notesListWidth += delta;
      _notesListWidth =
          _notesListWidth.clamp(_minNotesListWidth, _maxNotesListWidth);
    });
  }

  Future<void> _addFolder() async {
    await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Folder'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter folder name'),
          controller: _folderController,
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('Create'),
            onPressed: () async {
              final textField = _folderController.text;
              if (textField.isNotEmpty) {
                if (textField.isNotEmpty) {
                  await _notesController.addFolder(textField);
                  Navigator.of(context).pop(textField);
                  await _loadData();
                  setState(() {
                    _selectedNoteId = -1;
                    _folderController.clear();
                    _noteController.clear();
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Folder name cannot be empty')),
                  );
                }
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
    );
  }

  void _filterNotes() {
    _notesController.filterNotes(_searchController.text);
    setState(() {});
  }

  void _handleNoteInput() {
    if (_pageControllers.first.text.isEmpty && _selectedNoteId == -1) {
      print('handle add note');
      _addNote(_pageControllers.first.text);
    }
  }

  Future<void> _addNote([String initialContent = '']) async {
    try {
      final id = await _notesController.addNote(initialContent);
      setState(() {
        _selectedNoteId = id;
        _newNoteId = id;
        _pageControllers = [_pageControllers.first];
        _pageFocusNodes = [_pageFocusNodes.first];
      });
      await _notesController.addPage(id, initialContent);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToNote(id);
      });
      setState(() {
        _pageControllers.first.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add note: $e')),
      );
    }
  }

  Future<void> _handleNoteSelection(int noteId) async {
    if (_newNoteId != null &&
        _newNoteId != noteId &&
        _pageControllers.first.text.isEmpty) {
      await _deleteNote(_newNoteId!);
      _newNoteId = null;
    }
    setState(() {
      _selectedNoteId = noteId;
    });
    await _notesController.loadPages(noteId);
    _loadPagesForNote(noteId);
  }

  void _scrollToNote(int id) {
    final index =
        _notesController.filteredNotes.indexWhere((note) => note.id == id);
    if (index != -1) {
      _scrollController.animateTo(
        index * 56.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _updateCurrentPage() {
    if (_pageControllers.isNotEmpty) {
      final currentPosition = _pageScrollController.position.pixels;
      final maxPosition = _pageScrollController.position.maxScrollExtent;
      final pageHeight = maxPosition / (_pageControllers.length - 1);
      int newPage = (currentPosition / pageHeight).round() + 1;
      if (newPage != _currentPage) {
        setState(() {
          _currentPage = newPage;
          _pageNumberController.text = _currentPage.toString();
        });
      }
    }
  }

  void _scrollToPage(int pageNumber) {
    if (pageNumber > 0 && pageNumber <= _pageControllers.length) {
      final maxScrollExtent = _pageScrollController.position.maxScrollExtent;
      final scrollPosition =
          (pageNumber - 1) * (maxScrollExtent / (_pageControllers.length - 1));

      if (scrollPosition.isFinite &&
          scrollPosition >= 0 &&
          scrollPosition <= maxScrollExtent) {
        _pageScrollController.animateTo(
          scrollPosition,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        setState(() {
          _currentPage = pageNumber;
          _pageNumberController.text = _currentPage.toString();
        });
      } else {
        print('Invalid scroll position: $scrollPosition');
      }
    } else {
      print('Invalid page number: $pageNumber');
    }
  }

  Future<void> _updateNote() async {
    if (_selectedNoteId != -1) {
      try {
        final allContent = _pageControllers.map((c) => c.text).join('\n\n');
        await _notesController.updateNote(_selectedNoteId, allContent);
        for (int i = 0; i < _pageControllers.length; i++) {
          final page = _notesController.pages[i];
          page.content = _pageControllers[i].text;
          await _notesController.updatePage(page);
        }
        // Calling _loadData is causing an issue. In reality, you only need to update the state to reflect what was saved to the database
        //await _loadData();
        // use setState instead of _loadData
        setState(
          () {},
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update note: $e')),
        );
      }
    }
  }

  Future<void> _deleteNote(int id) async {
    try {
      await _notesController.deleteNote(id);
      await _loadData();
      if (_selectedNoteId == id) {
        setState(() {
          _selectedNoteId = -1;
          _pageControllers = [TextEditingController()];
          _pageFocusNodes = [FocusNode()];
          _pageControllers.first.addListener(_handleNoteInput);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete note: $e')),
      );
    }
  }

  void _deleteSelectedItem() {
    if (_selectedNoteId != -1) {
      _showDeleteNoteDialog();
    } else if (_notesController.selectedFolderId != null) {
      _showDeleteFolderDialog();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No note or folder selected')),
      );
    }
  }

  void _showDeleteNoteDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ShowDeleteNoteDialog(
            selectedNoteId: _selectedNoteId, onDelete: _deleteNote);
      },
    );
  }

  void _showDeleteFolderDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Folder'),
          content: const Text(
              'Are you sure you want to delete this folder? All the notes inside it will be deleted.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () {
                Navigator.of(context).pop();
                if (_notesController.selectedFolderId != null &&
                    _notesController.selectedFolderId! > 0) {
                  _deleteFolder(_notesController.selectedFolderId!);
                  setState(() {
                    _noteController.clear();
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('No valid folder selected for deletion')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteFolder(int folderId) async {
    try {
      await _notesController.deleteFolder(folderId);
      await _loadData();
      setState(() {
        _notesController.setSelectedFolderId(null);
        _selectedNoteId = -1;
        _pageControllers = [TextEditingController()];
        _pageFocusNodes = [FocusNode()];
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete folder: $e')),
      );
    }
  }

  void _deletePage(int index) {
    if (_selectedNoteId != -1 && index > 0) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Delete Page'),
            content: const Text('Are you sure you want to delete this page?'),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancel'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: const Text('Delete'),
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _pageControllers.removeAt(index);
                    _pageFocusNodes.removeAt(index);
                    _notesController.deletePage(_selectedNoteId, index);
                  });
                  _updateNote();
                },
              ),
            ],
          );
        },
      );
    }
  }

// In your NotesHomePage class
  void _navigateToPromptsAndRefresh() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) =>
              PromptsHomePage(selectedNoteId: _selectedNoteId)),
    );
    _loadData();
  }

  void _toggleAiPrompt(int pageIndex) {
    setState(() {
      if (_showAiPrompt && _currentPage == pageIndex + 1) {
        _showAiPrompt = false;
      } else {
        _showAiPrompt = true;
        if (pageIndex >= 0 && pageIndex < _pageControllers.length) {
          _currentPage = pageIndex + 1;
          _scrollToPage(_currentPage);
        } else {
          print('Invalid page index: $pageIndex');
        }
      }
    });
  }

  Future<void> _applyAiPrompt(int pageIndex) async {
    final selectedContent = _pageControllers[pageIndex].text;
    final prompt = _aiPromptController.text;

    if (prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a prompt')),
      );
      return;
    }

    setState(() {
      _isLoadingAiResponse = true;
    });

    try {
      final fullPrompt = "$prompt\n<input>\n$selectedContent\n</input>";
      final response = await chatWithGpt(fullPrompt);

      setState(() {
        _pageControllers[pageIndex].text = response;
        _isLoadingAiResponse = false;
      });

      _aiPromptController.clear();
      _toggleAiPrompt(pageIndex);
      await _updateNote();
    } catch (e) {
      setState(() {
        _isLoadingAiResponse = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating AI response: $e')),
      );
    }
  }

  void _executeFavoritePrompt(int favoriteId) async {
    final favoritePrompt =
        await _promptsController.getFavoritePrompt(favoriteId);
    if (favoritePrompt != null) {
      if (_selectedNoteId != -1) {
        String? firstPageContent =
            await _notesController.getFirstPageContent(_selectedNoteId);
        if (firstPageContent != null) {
          String fullPrompt =
              "${favoritePrompt.content}\n<input>\n$firstPageContent\n</input>";
          try {
            final result = await chatWithGpt(fullPrompt);
            await _notesController.addPage(_selectedNoteId, result);
            _loadData();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('New page added with favorite prompt result')),
            );
            setState(() {});
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content:
                      Text('Error executing favorite prompt: ${e.toString()}')),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No content found in the first page')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No note selected')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('No favorite prompt set for Favorite $favoriteId')),
      );
    }
  }

  Future<void> _getFavoritePromptTitle(int favoriteId) async {
    try {
      final title = await _promptsController.getFavoritePromptTitle(favoriteId);
      setState(() {
        if (favoriteId == 1) {
          _favoritePromptTitle1 = title;
        } else if (favoriteId == 2) {
          _favoritePromptTitle2 = title;
        } else if (favoriteId == 3) {
          _favoritePromptTitle3 = title;
        }
      });
    } catch (e) {
      setState(() {
        if (favoriteId == 1) {
          _favoritePromptTitle1 = 'Error getting prompt title: $e';
        } else if (favoriteId == 2) {
          _favoritePromptTitle2 = 'Error getting prompt title: $e';
        } else if (favoriteId == 3) {
          _favoritePromptTitle3 = 'Error getting prompt title: $e';
        }
      });
    }
  }

  void _showMoveFolderDialog(int noteId) async {
    final folders = await _notesController.getFolders();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to Folder'),
        content: SizedBox(
          width: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: folders.length,
            itemBuilder: (context, index) {
              final folder = folders[index];
              return ListTile(
                title: Text(folder['name']),
                onTap: () async {
                  await _notesController.moveNoteToFolder(noteId, folder['id']);
                  Navigator.of(context).pop();
                  await _loadData();
                },
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupedNotes = _notesController.groupNotes();

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: [
            const Text('My Notes'),
            const SizedBox(width: 8),
            _AppBarIconButton(
              assetPath: 'lib/icons/sidebar_icon.png',
              onPressed: () {
                setState(() {
                  _isFolderListVisible = !_isFolderListVisible;
                  _folderListWidth =
                      _isFolderListVisible ? _minFolderListWidth : 0;
                });
              },
              tooltip: _isFolderListVisible ? 'Hide folders' : 'Show folders',
            ),
            const SizedBox(width: 4),
            _AppBarIconButton(
              assetPath: 'lib/icons/create_icon.png',
              onPressed: () => _addNote(),
              tooltip: 'Create Note',
            ),
            const SizedBox(width: 4),
            _AppBarIconButton(
              assetPath: 'lib/icons/delete_icon.png',
              onPressed: _deleteSelectedItem,
              tooltip: 'Delete',
            ),
            const SizedBox(width: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Page',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 28,
                    child: TextField(
                      controller: _pageNumberController,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        isDense: true,
                        filled: false,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: (value) {
                        int? pageNumber = int.tryParse(value);
                        if (pageNumber != null) {
                          _scrollToPage(pageNumber);
                        }
                      },
                    ),
                  ),
                  Text(
                    ' / ${_pageControllers.length}',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_favoritePromptTitle1 != null)
            _FavoritePromptChip(
              label: _favoritePromptTitle1!,
              onPressed: () => _executeFavoritePrompt(1),
            ),
          if (_favoritePromptTitle2 != null)
            _FavoritePromptChip(
              label: _favoritePromptTitle2!,
              onPressed: () => _executeFavoritePrompt(2),
            ),
          if (_favoritePromptTitle3 != null)
            _FavoritePromptChip(
              label: _favoritePromptTitle3!,
              onPressed: () => _executeFavoritePrompt(3),
            ),
          const SizedBox(width: 6),
          _AppBarIconButton(
            assetPath: 'lib/icons/ai_icon.png',
            onPressed: _navigateToPromptsAndRefresh,
            tooltip: 'All Prompts',
            tinted: true,
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 280,
            height: 40,
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search notes...',
                hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                prefixIcon: Icon(Icons.search,
                    size: 20, color: colorScheme.onSurfaceVariant),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                _filterNotes();
              },
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
        children: [
          if (_isFolderListVisible) ...[
            SizedBox(
              width: _folderListWidth,
              child: Container(
                color: AppTheme.sidebarBackground(context),
                child: Column(
                  children: [
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          Text(
                            'FOLDERS',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: _notesController.folders.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: ListTile(
                                dense: true,
                                leading: const Icon(Icons.folder_copy_outlined,
                                    size: 19, color: AppTheme.folderIconColor),
                                title: const Text('All Notes'),
                                selected:
                                    _notesController.selectedFolderId == null,
                                onTap: () {
                                  setState(() {
                                    _notesController.setSelectedFolderId(null);
                                  });
                                  _loadData();
                                },
                              ),
                            );
                          }
                          final folder = _notesController.folders[index - 1];
                          final isSelected =
                              _notesController.selectedFolderId ==
                                  folder['id'];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: GestureDetector(
                              onSecondaryTapDown: (details) {
                                _showFolderContextMenu(context, folder['id'],
                                    folder['name'], details.globalPosition);
                              },
                              child: ListTile(
                                dense: true,
                                leading: Icon(Icons.folder_outlined,
                                    size: 19,
                                    color: isSelected
                                        ? colorScheme.onPrimaryContainer
                                        : colorScheme.onSurfaceVariant),
                                title: Text(folder['name']),
                                selected: isSelected,
                                onTap: () {
                                  setState(() {
                                    _notesController
                                        .setSelectedFolderId(folder['id']);
                                  });
                                  _loadData();
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.add_circle_outline,
                            size: 19, color: colorScheme.primary),
                        title: Text(
                          'New Folder',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onTap: _addFolder,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                onPanUpdate: (details) {
                  _updateFolderListWidth(details.delta.dx);
                },
                child: Container(
                  width: 1,
                  color: AppTheme.resizeHandleColor(context),
                ),
              ),
            ),
          ],
          SizedBox(
            width: _notesListWidth,
            child: Container(
              color: AppTheme.panelBackground(context),
              child: groupedNotes.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          'No notes yet.\nTap + above to create one.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 13),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      itemCount: groupedNotes.length,
                      itemBuilder: (context, index) {
                        final groupTitle = groupedNotes.keys.elementAt(index);
                        final notes = groupedNotes[groupTitle]!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
                              child: Text(
                                groupTitle.toUpperCase(),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                  letterSpacing: 0.6,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            ...notes.map(
                              (note) {
                                final isSelected = note.id == _selectedNoteId;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: GestureDetector(
                                    onSecondaryTapDown: (details) {
                                      _showNoteContextMenu(
                                          context,
                                          note.id!,
                                          note.title,
                                          details.globalPosition);
                                    },
                                    child: ListTile(
                                      dense: true,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        side: isSelected
                                            ? BorderSide.none
                                            : BorderSide(
                                                color: colorScheme
                                                    .outlineVariant
                                                    .withOpacity(0.5)),
                                      ),
                                      title: Text(
                                        note.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                        ),
                                      ),
                                      subtitle: Text(
                                        DateFormat('dd/MM/yyyy HH:mm')
                                            .format(note.timestamp),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isSelected
                                              ? colorScheme.onPrimaryContainer
                                                  .withOpacity(0.8)
                                              : colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      selected: isSelected,
                                      onTap: () =>
                                          _handleNoteSelection(note.id!),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            child: GestureDetector(
              onPanUpdate: (details) {
                _updateNotesListWidth(details.delta.dx);
              },
              child: Container(
                width: 1,
                color: AppTheme.resizeHandleColor(context),
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return ListView.builder(
                  controller: _pageScrollController,
                  itemCount: _pageControllers.length,
                  itemBuilder: (context, index) {
                    final colorScheme = Theme.of(context).colorScheme;
                    return Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      constraints: BoxConstraints(
                        minHeight: 400,
                        maxHeight: constraints.maxHeight -
                            32, // Subtracting vertical margins
                      ),
                      child: IntrinsicHeight(
                        child: Container(
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: colorScheme.outlineVariant
                                    .withOpacity(0.5)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                spreadRadius: 0,
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              // Page content
                              Container(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 27, vertical: 30),
                                child: TextField(
                                  controller: _pageControllers[index],
                                  maxLines: null,
                                  expands: true,
                                  decoration: InputDecoration(
                                    hintText: 'Write your note here...',
                                    border: InputBorder.none,
                                    filled: false,
                                    contentPadding: EdgeInsets.zero,
                                    hintStyle: TextStyle(
                                        color: colorScheme.onSurfaceVariant
                                            .withOpacity(0.7)),
                                  ),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    height: 1.6,
                                  ),
                                  onChanged: (text) {
                                    _updateNote();
                                  },
                                ),
                              ),

                              Positioned(
                                bottom: 4,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: IconButton(
                                    icon: Icon(Icons.add_circle_outline,
                                        color: colorScheme.onSurfaceVariant,
                                        size: 20),
                                    onPressed: () => _addNewPage(index),
                                    tooltip: 'Add Page',
                                  ),
                                ),
                              ),
                              if (index > 0)
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: IconButton(
                                    icon: Icon(Icons.delete_outline,
                                        color: colorScheme.onSurfaceVariant,
                                        size: 20),
                                    onPressed: () => _deletePage(index),
                                    tooltip: 'Delete Page',
                                  ),
                                ),
                              // Page number
                              Positioned(
                                bottom: 10,
                                right: 12,
                                child: Text(
                                  'Page ${index + 1}',
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 8,
                                right: 55,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (_showAiPrompt &&
                                        _currentPage == index + 1)
                                      Container(
                                        width: 400,
                                        margin:
                                            const EdgeInsets.only(bottom: 10),
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: colorScheme.surface,
                                          borderRadius:
                                              BorderRadius.circular(18),
                                          border: Border.all(
                                              color: colorScheme.outlineVariant
                                                  .withOpacity(0.6)),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Colors.black.withOpacity(0.1),
                                              spreadRadius: 0,
                                              blurRadius: 16,
                                              offset: const Offset(0, 6),
                                            ),
                                          ],
                                        ),
                                        child: SingleChildScrollView(
                                          child: TextField(
                                            maxLines: 5,
                                            minLines:
                                                1, // allows the TextField to grow vertically
                                            controller: _aiPromptController,
                                            style:
                                                const TextStyle(fontSize: 14),
                                            decoration: InputDecoration(
                                              hintText:
                                                  'Ask AI to edit this page…',
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                borderSide: BorderSide.none,
                                              ),
                                              filled: true,
                                              fillColor: colorScheme
                                                  .surfaceContainerHighest
                                                  .withOpacity(0.4),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                borderSide: BorderSide(
                                                  color: colorScheme.primary,
                                                  width: 1.6,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (_showAiPrompt &&
                                            _currentPage == index + 1)
                                          ElevatedButton(
                                            onPressed: () =>
                                                _applyAiPrompt(index),
                                            style: ElevatedButton.styleFrom(
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 8),
                                            ),
                                            child: const Text('Apply'),
                                          ),
                                        const SizedBox(width: 8),
                                        Tooltip(
                                          message: 'AI Support',
                                          child: Material(
                                            color: (_showAiPrompt &&
                                                    _currentPage == index + 1)
                                                ? colorScheme.primaryContainer
                                                : colorScheme
                                                    .surfaceContainerHighest
                                                    .withOpacity(0.5),
                                            shape: const CircleBorder(),
                                            child: InkWell(
                                              customBorder:
                                                  const CircleBorder(),
                                              onTap: () =>
                                                  _toggleAiPrompt(index),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(6.0),
                                                child: Icon(
                                                  _showAiPrompt &&
                                                          _currentPage ==
                                                              index + 1
                                                      ? Icons.close
                                                      : Icons.auto_awesome,
                                                  color: (_showAiPrompt &&
                                                          _currentPage ==
                                                              index + 1)
                                                      ? colorScheme
                                                          .onPrimaryContainer
                                                      : colorScheme.primary,
                                                  size: 16,
                                                ),
                                              ),
                                            ),
                                          ),
                                        )
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              if (_isLoadingAiResponse)
                                Positioned.fill(
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 24, vertical: 20),
                                      decoration: BoxDecoration(
                                        color: colorScheme.surface
                                            .withOpacity(0.92),
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        border: Border.all(
                                            color: colorScheme.outlineVariant
                                                .withOpacity(0.5)),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2.4),
                                          ),
                                          const SizedBox(height: 14),
                                          Text('Generating AI response...',
                                              style: TextStyle(
                                                  color: colorScheme
                                                      .onSurfaceVariant,
                                                  fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// A consistent, theme-aware icon button for the app bar, replacing the
/// old bare `Image.asset` + `IconButton` combos.
class _AppBarIconButton extends StatelessWidget {
  const _AppBarIconButton({
    required this.assetPath,
    required this.onPressed,
    required this.tooltip,
    this.tinted = false,
  });

  final String assetPath;
  final VoidCallback onPressed;
  final String tooltip;
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: tinted
            ? colorScheme.primaryContainer.withOpacity(0.6)
            : Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Image.asset(assetPath, width: 20, height: 20),
          ),
        ),
      ),
    );
  }
}

/// A small pill-shaped chip for a favorite AI prompt shortcut.
class _FavoritePromptChip extends StatelessWidget {
  const _FavoritePromptChip({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, size: 15, color: colorScheme.primary),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 100),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
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
