# The version comes from packaging/version.sh: rpmbuild --define "pkgver $(packaging/version.sh)"
Name:           snipshot
Version:        %{pkgver}
Release:        1%{?dist}
Summary:        Screenshots, screen recordings and text extraction for Wayland
License:        GPL-3.0-or-later AND MIT
URL:            https://github.com/ItzELECTR0/SnipShot
Source:         %{name}.tar.gz
ExclusiveArch:  x86_64 aarch64

# Zig 0.17 is newer than Fedora's, so it is not listed and has to be on PATH.
BuildRequires:  cmake
BuildRequires:  gcc-c++
BuildRequires:  ninja-build
BuildRequires:  cmake(LayerShellQt)
BuildRequires:  cmake(Qt6DBus)
BuildRequires:  cmake(Qt6Multimedia)
BuildRequires:  cmake(Qt6Qml)
BuildRequires:  cmake(Qt6Quick)
BuildRequires:  cmake(Qt6QuickControls2)

Requires:       grim
Requires:       gtk3
Requires:       layer-shell-qt
Requires:       qt6qml(QtMultimedia)
Requires:       qt6qml(QtQuick)
Requires:       qt6qml(QtQuick.Controls.Basic)
Requires:       qt6qml(QtQuick.Effects)
Requires:       qt6qml(QtQuick.Layouts)
Requires:       qt6qml(QtQuick.Shapes)
Requires:       tesseract
Requires:       tesseract-langpack-eng
Requires:       wl-clipboard
Recommends:     /usr/bin/ffmpeg
Recommends:     wf-recorder
Recommends:     xdg-desktop-portal

%description
SnipShot snips a rectangle, a window, a screen or a freeform shape, records an
area with audio, and reads the text in an area with Tesseract.

%prep
%autosetup -n %{name}
cp ui/icons/LICENSE fluentui-system-icons-LICENSE

%build
%cmake -G Ninja
%cmake_build

%install
%cmake_install
install -Dm644 data/themes/Midnight.json %{buildroot}%{_docdir}/%{name}/themes/Midnight.json

%check
ZIG_GLOBAL_CACHE_DIR=$PWD/zig-cache zig test src/core.zig -lc

%files
%license LICENSE fluentui-system-icons-LICENSE
%{_bindir}/snipshot
%{_datadir}/applications/net.electris.SnipShot.desktop
%{_docdir}/%{name}/
