- Full example mini.test implementation: https://github.com/MagicDuck/grug-far.nvim/tree/main
- Template repo originally used for this project: https://github.com/shortcuts/neovim-plugin-boilerplate

---

## Design Questions ✅ RESOLVED

- ✅ How do I navigate within the panel? → **Use vim motions (j/k, arrows) within the split window**

- ✅ How do I hide the panel? → **Press `q` or `<Esc>` to close**

- ✅ How do I expand it to handle cut off text? → **Press `<Tab>` for focus mode (double height + preview)**

- ✅ How do I handle clearing the panel and replacing the content when same list is appended? → **Automatic content refresh**

- ✅ How do I view the previews? How do I view the call stack? → **Focus mode shows preview + navigation stack**

- ✅ How do I reset the callstack when I've gone on to something else in the code base? → **Session management + bookmarks**

- ✅ I want breadcrumbs to track the process of exploration visible at all times → **Navigation stack with history**

- ✅ Showing a Window split instead of a panel opens up more opportunities to preserve context and show previews → **IMPLEMENTED: Split window architecture with focus mode**
