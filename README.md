# BeaverSVN 
# 🐚 BeaverSVN: The Lightweight GUI Client 

[![Platform](https://img.shields.io/badge/Platform-macOS-lightgrey)](https://www.apple.com/macos/)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)
[![Engine](https://img.shields.io/badge/SVN-1.14+-orange)](https://subversion.apache.org/)

BeaverSVN is a native macOS graphical user interface built to simplify version control workflows. Unlike heavy, paid alternatives, BeaverSVN provides a clean UI while leveraging the robust **Apache Subversion (SVN)** core, **APR (Apache Portable Runtime)**, and **APR-Util** for high-performance repository management.

## ✨ Why BeaverSVN?

* **Completely Free:** No subscriptions, no "Pro" versions—just full SVN power.
* **Native Performance:** Built using optimized `subversion` and `apr` libraries for fast checkout, commit, and update operations.
* **Intuitive UI:** Manage working copies, view logs, and resolve conflicts without touching the Terminal.
* **Universal Compatibility:** Works seamlessly with standard SVN repositories (HTTP, HTTPS, SVN, and SVN+SSH).

## 🛠 Built With

* **Subversion Core:** The industry-standard version control engine.
* **Apache APR & APR-Util:** For cross-platform compatibility and memory management.
* **macOS Frameworks:** For a smooth, integrated desktop experience.

## 🚀 Installation

1. **Download** the latest `BeaverSVN_Installer.dmg` from the [Releases](https://github.com/ashwinachu9525/BeaverSVN/releases) page.
2. **Drag** `BeaverSVN.app` to your `/Applications` folder.
3. **Run the Setup:** Because this is an independent build, you must clear the macOS quarantine flag to allow the bundled SVN binaries to run:
   
   Open Terminal and run:
   ```bash
   xattr -cr /Applications/FreeSVN.app
