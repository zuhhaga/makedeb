// Function - Set PKGBUILD functions for PKGBUILDs in src/PKGBUILDs
local configurePKGBUILD() = {
  name: "Configure PKGBUILDs",
  kind: "pipeline",
  type: "docker",
  clone: { disable: true },
  image_pull_secrets: [ "nexus_repository_docker_login" ],
  steps: [
    {
      name: "Clone",
      image: "docker.hunterwittenborn.com/hwittenborn/drone-git",
      settings: {
        action: "clone",
        ssh_known_hosts: { from_secret: "ssh_known_hosts" },
        ssh_key: { from_secret: "kavplex_github_ssh_key" }
      }
    },

    {
      name: "Set Variables in PKGBUILDs",
      image: "ubuntu",
      commands: [ "cd ${DRONE_REPO_NAME}", "scripts/pkgbuild_gen.sh" ]
    },

    {
      name: "Push Modified PKGBUILDs Back to GitHub",
      image: "docker.hunterwittenborn.com/hwittenborn/drone-git",
      settings: {
        action: "push",
        ssh_known_hosts: { from_secret: "ssh_known_hosts" },
        ssh_key: { from_secret: "kavplex_github_ssh_key" },
        message: "Updated version in PKGBUILDs [CI SKIP]"
      }
    }
  ]
};

// Function - Build and Publish
local buildAndPublish(nameCap, name) = {
  name: "Build and Publish to APT Repository (" + nameCap + " Release)",
  kind: "pipeline",
  type: "docker",
//  clone: { disable: true },
  depends_on: [ "Configure PKGBUILDs" ],
  trigger: {
    branch: name
  },
  steps: [
//    githubClone(),
    {
      name: "Build",
      image: "ubuntu",
      environment: {
        release_type: name,
        DEBIAN_FRONTEND: "noninteractive"
      },
      commands: [ "scripts/build.sh" ]
    },

    {
      name: "Publish",
      image: "ubuntu",
      environment: {
        nexus_repository_password: {
          from_secret: "nexus_repository_password"
        },
        DEBIAN_FRONTEND: "noninteractive"
      },
      commands: [ "scripts/publish.sh" ]
    }
  ]
};

local publishAUR(nameCap, name) = {
  name: "Publish to AUR (" + nameCap + " Release)",
  kind: "pipeline",
  type: "docker",
  depends_on: [ "Build and Publish to APT Repository (" + nameCap + " Release)" ],
  steps: [
    {
      name: "Pull Git repository from AUR",
      image: "docker.hunterwittenborn.com/hwittenborn/drone-aur",
      settings: {
        action: "clone",
        ssh_known_hosts: { from_secret: "ssh_known_hosts" },
        ssh_key: { from_secret: "kavplex_github_ssh_key" }
      }
    },

    {
      name: "Replace AUR PKGBUILD with PKGBUILD from GitHub",
      image: "ubuntu",
      environment: { "release_type": name },
      steps: [ "scripts/aur_pkgbuild_select.sh" ]
    },

    {
      name: "Push Release to AUR",
      image: "docker.hunterwittenborn.com/hwittenborn/drone-aur",
      settings: {
        action: "push",
        ssh_known_hosts: { from_secret: "ssh_known_hosts" },
        ssh_key: { from_secret: "kavplex_github_ssh_key" }
      }

    }
  ]
};

// Run Functions
[
  configurePKGBUILD(),
  buildAndPublish("Stable", "stable"),
  buildAndPublish("Alpha", "alpha"),
  publishAUR("Stable", "stable"),
  publishAUR("Alpha", "alpha"),
]