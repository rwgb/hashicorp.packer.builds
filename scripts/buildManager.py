#!/usr/bin/env python3
"""
Packer Build Manager

A comprehensive tool for managing Packer builds in the hashicorp.packer.builds repository.
Provides granular control over build execution, source selection, and variable management.

Usage:
    # Interactive mode - select builds from menu
    python buildManager.py
    
    # Build specific OS with auto-discovery
    python buildManager.py --os debian-12
    
    # Build with custom variables file
    python buildManager.py --os debian-12 --vars /path/to/custom.auto.pkrvars.hcl
    
    # Build specific source
    python buildManager.py --source proxmox-iso.debian_12_base
    
    # List all available builds
    python buildManager.py --list
    
    # Validate only (no build)
    python buildManager.py --os debian-12 --validate-only
    
    # Force init even if already initialized
    python buildManager.py --os debian-12 --force-init
"""

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple


class Colors:
    """ANSI color codes for terminal output"""
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'


class PackerBuild:
    """Represents a single Packer build configuration"""
    
    def __init__(self, path: Path, cloud_provider: str, os_type: str):
        self.path = path
        self.cloud_provider = cloud_provider
        self.os_type = os_type
        self.sources = self._discover_sources()
        self.build_name = self._get_build_name()
        self.variables_file = path / "variables.auto.pkrvars.hcl"
    
    def _discover_sources(self) -> List[str]:
        """Discover all sources defined in sources.pkr.hcl"""
        sources_file = self.path / "sources.pkr.hcl"
        if not sources_file.exists():
            return []
        
        sources = []
        content = sources_file.read_text()
        
        # Match: source "type" "name" {
        pattern = r'source\s+"([^"]+)"\s+"([^"]+)"\s*{'
        for match in re.finditer(pattern, content):
            source_type = match.group(1)
            source_name = match.group(2)
            sources.append(f"{source_type}.{source_name}")
        
        return sources
    
    def _get_build_name(self) -> str:
        """Extract build name from build.pkr.hcl"""
        build_file = self.path / "build.pkr.hcl"
        if not build_file.exists():
            return self.path.name
        
        content = build_file.read_text()
        
        # Match: build { name = "name"
        match = re.search(r'build\s*{\s*name\s*=\s*"([^"]+)"', content)
        if match:
            return match.group(1)
        
        return self.path.name
    
    def __repr__(self):
        return f"PackerBuild({self.cloud_provider}/{self.os_type}/{self.path.name})"


class PackerBuildManager:
    """Main build manager class"""
    
    def __init__(self, repo_root: Optional[Path] = None):
        self.repo_root = repo_root or self._find_repo_root()
        self.builds_dir = self.repo_root / "builds"
        self.builds = self._discover_builds()
    
    def _find_repo_root(self) -> Path:
        """Find repository root by looking for .git directory"""
        current = Path.cwd()
        while current != current.parent:
            if (current / ".git").exists():
                return current
            current = current.parent
        
        raise RuntimeError("Not in a git repository")
    
    def _discover_builds(self) -> List[PackerBuild]:
        """Discover all Packer builds in the repository"""
        builds = []
        
        if not self.builds_dir.exists():
            return builds
        
        # Walk through builds/{provider}/{os_type}/{distro}/{version}/
        for provider_dir in self.builds_dir.iterdir():
            if not provider_dir.is_dir() or provider_dir.name.startswith('.'):
                continue
            
            provider = provider_dir.name
            
            for os_dir in provider_dir.rglob("build.pkr.hcl"):
                build_path = os_dir.parent
                
                # Determine OS type based on path
                rel_path = build_path.relative_to(provider_dir)
                os_type = rel_path.parts[0] if rel_path.parts else "unknown"
                
                builds.append(PackerBuild(build_path, provider, os_type))
        
        return sorted(builds, key=lambda b: (b.cloud_provider, b.os_type, b.path.name))
    
    def list_builds(self) -> None:
        """List all discovered builds"""
        print(f"\n{Colors.BOLD}{Colors.HEADER}Available Packer Builds:{Colors.ENDC}\n")
        
        current_provider = None
        current_os = None
        
        for i, build in enumerate(self.builds, 1):
            if build.cloud_provider != current_provider:
                current_provider = build.cloud_provider
                print(f"\n{Colors.BOLD}{Colors.OKCYAN}📦 {current_provider.upper()}{Colors.ENDC}")
                current_os = None
            
            if build.os_type != current_os:
                current_os = build.os_type
                print(f"  {Colors.OKBLUE}└─ {current_os}{Colors.ENDC}")
            
            rel_path = build.path.relative_to(self.builds_dir)
            print(f"     {i:2d}. {Colors.OKGREEN}{build.build_name}{Colors.ENDC}")
            print(f"         Path: {rel_path}")
            print(f"         Sources: {', '.join(build.sources) if build.sources else 'None found'}")
            
            if build.variables_file.exists():
                print(f"         {Colors.WARNING}✓ Has variables.auto.pkrvars.hcl{Colors.ENDC}")
        
        print()
    
    def find_build_by_pattern(self, pattern: str) -> Optional[PackerBuild]:
        """Find a build by name pattern or path pattern"""
        pattern_lower = pattern.lower()
        
        for build in self.builds:
            # Check build name
            if pattern_lower in build.build_name.lower():
                return build
            
            # Check path
            if pattern_lower in str(build.path).lower():
                return build
            
            # Check simple name like "debian-12"
            simple_name = f"{build.path.parts[-2]}-{build.path.name}"
            if pattern_lower in simple_name.lower():
                return build
        
        return None
    
    def find_build_by_source(self, source: str) -> Optional[Tuple[PackerBuild, str]]:
        """Find a build that contains the specified source"""
        for build in self.builds:
            if source in build.sources:
                return (build, source)
            
            # Try partial match
            for build_source in build.sources:
                if source in build_source:
                    return (build, build_source)
        
        return None
    
    def run_packer_command(
        self,
        build: PackerBuild,
        command: str,
        source: Optional[str] = None,
        variables_file: Optional[Path] = None,
        extra_args: Optional[List[str]] = None,
        dry_run: bool = False
    ) -> int:
        """Execute a packer command"""
        
        cmd = ["packer", command]
        
        # Add source filter if specified
        if source and command in ["build", "validate"]:
            cmd.extend(["-only", source])
        
        # Add variables file
        if variables_file:
            if not variables_file.exists():
                print(f"{Colors.FAIL}Error: Variables file not found: {variables_file}{Colors.ENDC}")
                return 1
            cmd.extend(["-var-file", str(variables_file)])
        elif build.variables_file.exists():
            cmd.extend(["-var-file", str(build.variables_file)])
        
        # Add extra arguments
        if extra_args:
            cmd.extend(extra_args)
        
        # Add build directory
        cmd.append(".")
        
        print(f"\n{Colors.BOLD}{Colors.HEADER}Executing Packer Command:{Colors.ENDC}")
        print(f"{Colors.OKCYAN}  Working Directory: {build.path}{Colors.ENDC}")
        print(f"{Colors.OKCYAN}  Command: {' '.join(cmd)}{Colors.ENDC}\n")
        
        if dry_run:
            print(f"{Colors.WARNING}[DRY RUN] Command not executed{Colors.ENDC}")
            return 0
        
        try:
            result = subprocess.run(
                cmd,
                cwd=build.path,
                env={**os.environ, "PACKER_LOG": "1"},
                check=False
            )
            return result.returncode
        except KeyboardInterrupt:
            print(f"\n{Colors.WARNING}Build interrupted by user{Colors.ENDC}")
            return 130
        except Exception as e:
            print(f"{Colors.FAIL}Error executing packer: {e}{Colors.ENDC}")
            return 1
    
    def init_build(self, build: PackerBuild, force: bool = False) -> int:
        """Initialize packer build (download plugins)"""
        print(f"\n{Colors.BOLD}Initializing Packer build...{Colors.ENDC}")
        
        cmd = ["packer", "init"]
        if force:
            cmd.append("-upgrade")
        cmd.append(".")
        
        try:
            result = subprocess.run(cmd, cwd=build.path, check=False)
            if result.returncode == 0:
                print(f"{Colors.OKGREEN}✓ Initialization successful{Colors.ENDC}")
            return result.returncode
        except Exception as e:
            print(f"{Colors.FAIL}Error initializing packer: {e}{Colors.ENDC}")
            return 1
    
    def interactive_mode(self) -> None:
        """Interactive build selection"""
        print(f"\n{Colors.BOLD}{Colors.HEADER}╔═══════════════════════════════════════╗{Colors.ENDC}")
        print(f"{Colors.BOLD}{Colors.HEADER}║   Packer Build Manager (Interactive)  ║{Colors.ENDC}")
        print(f"{Colors.BOLD}{Colors.HEADER}╚═══════════════════════════════════════╝{Colors.ENDC}\n")
        
        if not self.builds:
            print(f"{Colors.FAIL}No builds found in {self.builds_dir}{Colors.ENDC}")
            return
        
        # Display builds
        print(f"{Colors.BOLD}Available builds:{Colors.ENDC}\n")
        for i, build in enumerate(self.builds, 1):
            rel_path = build.path.relative_to(self.builds_dir)
            print(f"  {i:2d}. {Colors.OKGREEN}{build.build_name}{Colors.ENDC} ({rel_path})")
        
        # Get user selection
        while True:
            try:
                selection = input(f"\n{Colors.BOLD}Select build number (or 'q' to quit): {Colors.ENDC}")
                if selection.lower() == 'q':
                    return
                
                idx = int(selection) - 1
                if 0 <= idx < len(self.builds):
                    break
                print(f"{Colors.FAIL}Invalid selection. Please choose 1-{len(self.builds)}{Colors.ENDC}")
            except ValueError:
                print(f"{Colors.FAIL}Invalid input. Please enter a number{Colors.ENDC}")
        
        build = self.builds[idx]
        
        # Select source if multiple
        source = None
        if len(build.sources) > 1:
            print(f"\n{Colors.BOLD}Available sources:{Colors.ENDC}")
            print(f"  0. All sources")
            for i, src in enumerate(build.sources, 1):
                print(f"  {i}. {src}")
            
            while True:
                try:
                    src_sel = input(f"\n{Colors.BOLD}Select source (0 for all): {Colors.ENDC}")
                    src_idx = int(src_sel)
                    if src_idx == 0:
                        break
                    if 1 <= src_idx <= len(build.sources):
                        source = build.sources[src_idx - 1]
                        break
                    print(f"{Colors.FAIL}Invalid selection{Colors.ENDC}")
                except ValueError:
                    print(f"{Colors.FAIL}Invalid input{Colors.ENDC}")
        elif len(build.sources) == 1:
            source = build.sources[0]
        
        # Select action
        print(f"\n{Colors.BOLD}Actions:{Colors.ENDC}")
        print(f"  1. Initialize (packer init)")
        print(f"  2. Validate")
        print(f"  3. Build")
        print(f"  4. Validate + Build")
        
        while True:
            action = input(f"\n{Colors.BOLD}Select action: {Colors.ENDC}")
            if action in ['1', '2', '3', '4']:
                break
            print(f"{Colors.FAIL}Invalid action{Colors.ENDC}")
        
        # Execute
        if action == '1':
            self.init_build(build, force=True)
        elif action == '2':
            self.run_packer_command(build, "validate", source)
        elif action == '3':
            self.run_packer_command(build, "build", source)
        elif action == '4':
            if self.run_packer_command(build, "validate", source) == 0:
                self.run_packer_command(build, "build", source)


def main():
    parser = argparse.ArgumentParser(
        description="Packer Build Manager - Manage and execute Packer builds",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    
    parser.add_argument(
        "--list", "-l",
        action="store_true",
        help="List all available builds"
    )
    
    parser.add_argument(
        "--os",
        help="Build specific OS (e.g., 'debian-12', 'windows-server-2019')"
    )
    
    parser.add_argument(
        "--source", "-s",
        help="Build specific source (e.g., 'proxmox-iso.debian_12_base')"
    )
    
    parser.add_argument(
        "--vars", "-v",
        type=Path,
        help="Path to custom variables.auto.pkrvars.hcl file"
    )
    
    parser.add_argument(
        "--validate-only",
        action="store_true",
        help="Only validate, don't build"
    )
    
    parser.add_argument(
        "--init-only",
        action="store_true",
        help="Only initialize (packer init)"
    )
    
    parser.add_argument(
        "--force-init",
        action="store_true",
        help="Force re-initialization (packer init -upgrade)"
    )
    
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show commands without executing"
    )
    
    parser.add_argument(
        "--repo-root",
        type=Path,
        help="Repository root path (auto-detected if not specified)"
    )
    
    parser.add_argument(
        "packer_args",
        nargs="*",
        help="Additional arguments to pass to packer"
    )
    
    args = parser.parse_args()
    
    try:
        manager = PackerBuildManager(args.repo_root)
    except RuntimeError as e:
        print(f"{Colors.FAIL}Error: {e}{Colors.ENDC}")
        return 1
    
    # List builds
    if args.list:
        manager.list_builds()
        return 0
    
    # Interactive mode if no arguments
    if not any([args.os, args.source]):
        manager.interactive_mode()
        return 0
    
    # Find build by source
    if args.source:
        result = manager.find_build_by_source(args.source)
        if not result:
            print(f"{Colors.FAIL}Error: Source '{args.source}' not found{Colors.ENDC}")
            print(f"\nRun '{sys.argv[0]} --list' to see available sources")
            return 1
        
        build, source = result
        print(f"{Colors.OKGREEN}Found source in: {build.build_name}{Colors.ENDC}")
    
    # Find build by OS pattern
    elif args.os:
        build = manager.find_build_by_pattern(args.os)
        if not build:
            print(f"{Colors.FAIL}Error: Build matching '{args.os}' not found{Colors.ENDC}")
            print(f"\nRun '{sys.argv[0]} --list' to see available builds")
            return 1
        
        source = None
        print(f"{Colors.OKGREEN}Found build: {build.build_name}{Colors.ENDC}")
    else:
        print(f"{Colors.FAIL}Error: Must specify --os or --source{Colors.ENDC}")
        return 1
    
    # Execute commands
    return_code = 0
    
    # Initialize if requested or forced
    if args.init_only or args.force_init:
        return_code = manager.init_build(build, force=args.force_init)
        if args.init_only:
            return return_code
    
    # Validate
    if args.validate_only or not args.init_only:
        return_code = manager.run_packer_command(
            build, "validate", source, args.vars, args.packer_args, args.dry_run
        )
        if args.validate_only or return_code != 0:
            return return_code
    
    # Build
    if not args.validate_only and not args.init_only:
        return_code = manager.run_packer_command(
            build, "build", source, args.vars, args.packer_args, args.dry_run
        )
    
    return return_code


if __name__ == "__main__":
    sys.exit(main())
