CURRENT_DIR = $(shell pwd)
# ansible-test path
ANSIBLE_TEST ?= $(shell which ansible-test)
# option to run ansible-test sanity: must be either venv or docker (default is docker)
ANSIBLE_TEST_MODE ?= docker
# Root path for MKDOCS content
WEBDOC_BUILD = ansible_collections/arista/avd/docs/_build

.PHONY: help
help: ## Display help message
	@grep -E '^[0-9a-zA-Z_-]+\.*[0-9a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

#########################################
# Ansible Collection actions		 	#
#########################################
.PHONY: collection-build
collection-build: ## Build arista.cvp collection locally
	ansible-galaxy collection build --force ansible_collections/arista/avd

.PHONY: collection-install
collection-install: ## Install arista.cvp collection to default location (~/.ansible/collections/ansible_collections)
	for collection in *.tar.gz; do \
		ansible-galaxy collection install $$collection ;\
	done

#########################################
# Code Validation using ansible-test 	#
#########################################

.PHONY: sanity
sanity: sanity-info sanity-lint sanity-import ## Run ansible-test sanity validation.

.PHONY: sanity-info
sanity-info: ## Show information about ansible-test
	cd ansible_collections/arista/avd/ ; ansible-test env

.PHONY: sanity-lint
sanity-lint: ## Run ansible-test sanity for code sanity
	cd ansible_collections/arista/avd/ ; \
	mkdir tests ; \
	ansible-test sanity --requirements --$(ANSIBLE_TEST_MODE) --skip-test import

.PHONY: sanity-import
sanity-import: ## Run ansible-test sanity for code import
	cd ansible_collections/arista/avd/ ; \
	mkdir tests ; \
	ansible-test sanity --requirements --$(ANSIBLE_TEST_MODE) --test import

#########################################
# Code Validation & CI Actions 			#
#########################################

.PHONY: linting
linting: ## Run pre-commit script for python code linting using pylint
	sh .github/lint-yaml
	sh .github/lint-python

.PHONY: pre-commit
pre-commit: ## Execute pre-commit validation for staged files
	pre-commit run

.PHONY: pre-commit-all
pre-commit-all: ## Execute pre-commit validation for all files
	pre-commit run --all-files

.PHONY: playbook-validation
playbook-validation: ## Run script to validate playbooks defined under testing/ folder
	sh .github/run-test-playbooks


#########################################
# Documentation actions					#
#########################################
.PHONY: webdoc
webdoc: ## Build documentation to publish static content
	( cd $(WEBDOC_BUILD) ; \
	python ansible2rst.py ; \
	mkdir ../modules/ ; \
	find . -name '*.rst' -exec pandoc {} --from rst --to gfm -o ../modules/{}.md \;)
	cp $(CURRENT_DIR)/contributing.md $(WEBDOC_BUILD)/.. ;\
	cp $(CURRENT_DIR)/development/README.md $(WEBDOC_BUILD)/../installation/development.md ;\
	cp -r $(CURRENT_DIR)/media $(WEBDOC_BUILD)/../ ;\
	cd $(CURRENT_DIR)
	mkdocs build -f mkdocs.yml


#########################################
# Misc Actions (configure CI runner) 	#
#########################################

.PHONY: github-configure-ci
github-configure-ci: github-configure-ci-python3 github-configure-ci-ansible ## Configure CI environment to run GA (Ubuntu:latest LTS)

.PHONY: github-configure-ci-ansible
github-configure-ci-ansible: ## Install Ansible Test 2.9 on GA (Ubuntu:latest LTS)
	sudo apt-get update
	sudo apt-get install -y gnupg2
	sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 93C4A3FD7BB9C367
	sudo echo "deb http://ppa.launchpad.net/ansible/ansible-2.9/ubuntu bionic main" | sudo tee /etc/apt/sources.list.d/ansible.list
	sudo echo "deb-src http://ppa.launchpad.net/ansible/ansible-2.9/ubuntu bionic main" | sudo tee -a /etc/apt/sources.list.d/ansible.list
	sudo apt-get update
	sudo DEBIAN_FRONTEND=noninteractive apt-get install -q -y ansible-test

.PHONY: github-configure-ci-python3
github-configure-ci-python3: ## Configure Python3 environment to run GA (Ubuntu:latest LTS)
	sudo apt-get update
	sudo apt-get upgrade -y
	sudo apt-get install -y python3 python3-pip git python3-setuptools
	sudo update-alternatives --install /usr/bin/python python /usr/bin/python3 10

.PHONY: install-requirements
install-requirements: ## Install python requirements for generic purpose
	pip3 install --upgrade wheel
	pip3 install -r development/requirements.txt
	pip3 install -r development/requirements-dev.txt

.PHONY: install-docker
install-docker: ## Install docker
	sudo apt install -q -y apt-transport-https ca-certificates curl software-properties-common
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
	sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable"
	sudo apt update
	sudo apt install -q -y docker-ce