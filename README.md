# 🌐 Collaborator Guide: Editing the MECH230 Dynamics Notes

Welcome to the team! This guide will help you set up your environment to contribute to our digital textbook. We use **Quarto** for the content and **Git** to keep our files synchronized.

Don't worry if you’ve never used these tools before—this walkthrough covers the essentials.

---

## 1. Initial Setup (One-Time Only)

Before you can edit the site, you need to install the software "engines" that run it.

### Install Software
1.  **VS Code:** Our primary text editor. Download it from [code.visualstudio.com](https://code.visualstudio.com/).
2.  **Quarto:** The publishing system. Download from [quarto.org](https://quarto.org/docs/get-started/).
3.  **Git:** The version control tool. Download from [git-scm.com](https://git-scm.com/).

### Install Necessary Packages
To ensure the diagrams and math render correctly, you need to install a few libraries. Open your **Terminal** (Mac) or **Command Prompt** (Windows) and run:

```bash
# Install the core Python tools we use for dynamics
pip install numpy matplotlib scipy

```

## 2. Getting the Project Files
1. Open VS Code.

2. Go to `File > Open Folder` and create a dedicated folder on your computer (e.g., Documents/MECH230-Notes).

3. Open the Terminal inside VS Code (`Terminal > New Terminal`).

4. Type the following command to download the project:
git clone `https://github.com/Your-Org-Name/MECH230-Dynamics-Notes.git`

## 3. How to Add or Edit Content
Quarto uses `.qmd` (Quarto Markdown) files. They are just text files where you can write naturally.

**Step 1: Create or Edit a File**

* To edit: Simply click an existing `.qmd` file and start typing.

* To create: Save a new file with the `.qmd` extension (e.g., `lesson-01.qmd`).

**Step 2: Preview Your Changes**

You can see what the website looks like before anyone else does. In the terminal, type:
`quarto preview`

A browser window will open. Every time you save your file, this page will automatically refresh to show your changes.

## 4. Saving Your Work (The Git Workflow)
When you are happy with your edits, you need to "save" them to the project history. Since I will handle the final publishing, you just need to follow these three "magic" commands in the terminal:

1. Stage your changes:
`git add .`
(This tells Git: "Get these files ready to save.")

2. Label your changes:
`git commit -m "Added notes for Chapter 1"`
(Replace the text in quotes with a brief description of what you did.)

3. Send them to the cloud:
`git push origin main`

[!IMPORTANT]
**Always run `git pull` before you start working!**
This ensures you have the latest version of the files that others might have updated.

## Troubleshooting
* "I broke the layout!" -> Don't panic. Just don't "push" the changes. Close the preview and undo your text edits.

* "Command not found" -> Ensure you restarted your computer after installing Quarto and Git.