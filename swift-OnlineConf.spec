Name:          swift-OnlineConf
Version:       %{__version}
Release:       %{!?__release:1}%{?__release}%{?dist}
Summary:       OnlineConf client

Group:         MAILRU
License:       MAILRU
URL:           https://gitlab.corp.mail.ru/mydev/%{name}
Source0:       %{name}-%{version}.tar.gz
BuildRoot:     %(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)

BuildRequires: swift
BuildRequires: swift-packaging

%swift_package_ssh_url
%swift_find_provides_and_requires

%description
OnlineConf client for Swift.

%{?__revision:Built from revision %{__revision}.}


%prep
%setup -q
%swift_patch_package


%build
%swift_build


%install
rm -rf %{buildroot}
%swift_install
%swift_install_devel


%clean
rm -rf %{buildroot}


%files
%defattr(-,root,root,-)
%{swift_libdir}/*.so
%{swift_moduledir}/*.swiftmodule
%{swift_moduledir}/*.swiftdoc
%{swift_clangmoduleroot}/CCKV
