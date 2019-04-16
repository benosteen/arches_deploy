#!/bin/bash

HELP_TEXT="

Arguments:
	run_arches: Default. Run the Arches server
	run_tests: Run unit tests
	setup_arches: Set up a fresh Arches instance
	-h or help: Display help text
"

display_help() {
	echo "${HELP_TEXT}"
}

APP_FOLDER=${ARCHES_ROOT}
PACKAGE_JSON_FOLDER=${ARCHES_ROOT}

# NB set CUSTOM_SCRIPT_FOLDER to the path of any installed custom scripts that need
# to be run before starting the server.

# Read modules folder from yarn config file
# Get string after '--install.modules-folder' -> get first word of the result 
# -> remove line endlings -> trim quotes -> trim leading ./
YARN_MODULES_FOLDER=${PACKAGE_JSON_FOLDER}/$(awk \
	-F '--install.modules-folder' '{print $2}' ${PACKAGE_JSON_FOLDER}/.yarnrc \
	| awk '{print $1}' \
	| tr -d $'\r' \
	| tr -d '"' \
	| sed -e "s/^\.\///g")

export DJANGO_PORT=${DJANGO_PORT:-8000}
COUCHDB_URL="http://$COUCHDB_USER:$COUCHDB_PASS@$COUCHDB_HOST:$COUCHDB_PORT"
STATIC_ROOT=${STATIC_ROOT:-/static_root}


cd_web_root() {
	cd ${WEB_ROOT}
	echo "Current work directory: ${WEB_ROOT}"
}

cd_arches_root() {
	cd ${ARCHES_ROOT}
	echo "Current work directory: ${ARCHES_ROOT}"
}

cd_app_folder() {
	cd ${APP_FOLDER}
	echo "Current work directory: ${APP_FOLDER}"
}

cd_yarn_folder() {
	cd ${PACKAGE_JSON_FOLDER}
	echo "Current work directory: ${PACKAGE_JSON_FOLDER}"
}

activate_virtualenv() {
	. ${WEB_ROOT}/ENV/bin/activate
}


#### Install

# Setup Postgresql and Elasticsearch, and load data
setup_arches() {
	cd_arches_root
	activate_virtualenv

	echo "Clearing and setting up Elasticsearch indices"
	echo "============================================="
	echo
	python manage.py es delete_indexes
	python manage.py es setup_indexes
	echo

	echo "Running: Creating couchdb system databases"
	echo "=========================================="
	echo
	curl -X PUT ${COUCHDB_URL}/_users
	curl -X PUT ${COUCHDB_URL}/_global_changes
	curl -X PUT ${COUCHDB_URL}/_replicator
	echo

	echo "Running migrations"
	echo "=================="
	echo
	run_migrations
	echo

	echo "Importing Arches system graphs"
	echo "=============================="
	echo
	python manage.py packages -o import_graphs \
	                          -s ${ARCHES_ROOT}/arches/db/system_settings/Arches_System_Settings_Model.json \
	                          -ow=overwrite

	python manage.py packages -o import_business_data \
	                          -s ${ARCHES_ROOT}/arches/db/system_settings/Arches_System_Settings.json \
	                          -ow=overwrite
	echo

	echo "Importing Concepts"
	echo "=================="
	echo
	if [ -x ${ARCHES_ROOT}/base_config/rdm/thesaurus.skos.xml ]
	then
		import_reference_data ${ARCHES_ROOT}/base_config/rdm/thesaurus.skos.xml
	fi
	if [ -x ${ARCHES_ROOT}/base_config/rdm/collections.skos.xml ]
	then
		import_reference_data ${ARCHES_ROOT}/base_config/rdm/collections.skos.xml
	fi
	echo

	echo "Importing Branches"
	echo "=================="
	echo
	python manage.py packages -o import_graphs \
	                          -s ${ARCHES_ROOT}/base_config/graphs/branches \
	                          -ow=overwrite
	echo

	echo "Importing Models"
	echo "================"
	echo
	python manage.py packages -o import_graphs \
	                          -s ${ARCHES_ROOT}/base_config/graphs/resource_models \
	                          -ow=overwrite
	echo
	echo "Re-running migrate"
	run_migrations

	install_yarn_components
}

wait_for_db() {
	echo "Testing if database server is up..."
	while [[ ! ${return_code} == 0 ]]
	do
				psql --host=${PGHOST} --port=${PGPORT} --user=${PGUSERNAME} --dbname=postgres -c "select 1" >&/dev/null
		return_code=$?
		sleep 1
	done
	echo "Database server is up"

		echo "Testing if Elasticsearch is up..."
		while [[ ! ${return_code} == 0 ]]
		do
				curl -s "http://${ESHOST}:${ESPORT}" >&/dev/null
				return_code=$?
				sleep 1
		done
		echo "Elasticsearch is up"
}

set_dev_mode() {
	echo ""
	echo ""
	echo "----- SETTING DEV MODE -----"
	echo ""
	cd_arches_root
	python ${ARCHES_ROOT}/setup.py develop
}

# Yarn
init_yarn_components() {
	if [[ ! -d ${YARN_MODULES_FOLDER} ]] || [[ ! "$(ls ${YARN_MODULES_FOLDER})" ]]; then
		echo "Yarn modules do not exist, installing..."
		install_yarn_components
	fi
}

# This is also done in Dockerfile, but that does not include user's custom Arches app package.json
# Also, the packages folder may have been overlaid by a Docker volume.
install_yarn_components() {
	echo ""
	echo ""
	echo "----- INSTALLING YARN COMPONENTS -----"
	echo ""
	cd_yarn_folder
	echo "Installing Yarn components to ${YARN_MODULES_FOLDER}"
	yarn install --modules-folder ${YARN_MODULES_FOLDER}
}

import_reference_data() {
	# Import example concept schemes
	local rdf_file="$1"
	echo "Running: python manage.py packages -o import_reference_data -s \"${rdf_file}\""
	python manage.py packages -o import_reference_data -s "${rdf_file}"
}

# Allows users to add scripts that are run on startup (after this entrypoint)
run_custom_scripts() {
	if [ -z "$CUSTOM_SCRIPT_FOLDER" ]
	then
		echo "CUSTOM_SCRIPT_FOLDER env var is not set. No custom scripts will be run."
	else
		for file in ${CUSTOM_SCRIPT_FOLDER}/*; do
			if [[ -f ${file} ]]; then
				echo ""
				echo ""
				echo "----- RUNNING CUSTOM SCRIPT: ${file} -----"
				echo ""
				source ${file}
			fi
		done
	fi
}

#### Run

run_migrations() {
	echo ""
	echo ""
	echo "----- RUNNING DATABASE MIGRATIONS -----"
	echo ""
	cd_app_folder
	python manage.py migrate
}

collect_static(){
	echo ""
	echo ""
	echo "----- COLLECTING DJANGO STATIC FILES -----"
	echo ""
	cd_app_folder
	python manage.py collectstatic --noinput
}


run_django_server() {
	echo ""
	echo ""
	echo "----- *** RUNNING DJANGO DEVELOPMENT SERVER *** -----"
	echo ""
	cd_app_folder
	if [[ ${DJANGO_REMOTE_DEBUG} != "True" ]]; then
			echo "Running Django with livereload."
		exec python manage.py runserver 0.0.0.0:${DJANGO_PORT}
	else
				echo "Running Django with options --noreload --nothreading for remote debugging."
		exec python manage.py runserver --noreload --nothreading 0.0.0.0:${DJANGO_PORT}
	fi
}


run_gunicorn_server() {
	echo ""
	echo ""
	echo "----- *** RUNNING GUNICORN PRODUCTION SERVER *** -----"
	echo ""
	cd_app_folder
	
	if [[ ! -z ${ARCHES_PROJECT} ]]; then
				gunicorn arches.wsgi:application \
						--config ${ARCHES_ROOT}/gunicorn_config.py \
						--pythonpath ${ARCHES_PROJECT}
	else
				gunicorn arches.wsgi:application \
						--config ${ARCHES_ROOT}/gunicorn_config.py
		fi
}



#### Main commands
run_arches() {

	if [[ "${DJANGO_MODE}" == "DEV" ]]; then
		set_dev_mode
	fi

	run_custom_scripts

	if [[ "${DJANGO_MODE}" == "DEV" ]]; then
		run_django_server
	elif [[ "${DJANGO_MODE}" == "PROD" ]]; then
		collect_static
		run_gunicorn_server
	fi
}


run_tests() {
	set_dev_mode
	echo ""
	echo ""
	echo "----- RUNNING ARCHES TESTS -----"
	echo ""
	cd_arches_root
	python manage.py test tests --pattern="*.py" --settings="tests.test_settings" --exe
	if [ $? -ne 0 ]; then
				echo "Error: Not all tests ran succesfully."
		echo "Exiting..."
				exit 1
	fi
}




### Starting point ###

activate_virtualenv

# Use -gt 1 to consume two arguments per pass in the loop (e.g. each
# argument has a corresponding value to go with it).
# Use -gt 0 to consume one or more arguments per pass in the loop (e.g.
# some arguments don't have a corresponding value to go with it, such as --help ).

# If no arguments are supplied, assume the server needs to be run
if [[ $#	-eq 0 ]]; then
	run_arches
fi

# Else, process arguments
echo "Full command: $@"
while [[ $# -gt 0 ]]
do
	key="$1"
	echo "Command: ${key}"

	case ${key} in
		run_arches)
			wait_for_db
			run_arches
		;;
		setup_arches)
			wait_for_db
			setup_arches
		;;
		run_tests)
			wait_for_db
			run_tests
		;;
		run_migrations)
			wait_for_db
			run_migrations
		;;
		install_yarn_components)
			install_yarn_components
		;;
		help|-h)
			display_help
		;;
		*)
						cd_app_folder
			"$@"
			exit 0
		;;
	esac
	shift # next argument or value
done
