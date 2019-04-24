import os
from django.core.exceptions import ImproperlyConfigured
import ast
import requests
import sys
from settings import *


def get_env_variable(var_name):
    msg = "Set the %s environment variable"
    try:
        return os.environ[var_name]
    except KeyError:
        error_msg = msg % var_name
        raise ImproperlyConfigured(error_msg)


def opt_env(var_name, default_response = ""):
    try:
        return os.environ[var_name]
    except KeyError:
        return default_response

ARCHES_NAMESPACE_FOR_DATA_EXPORT = 'http://localhost:8000/'

USER_ARCHES_NAMESPACE_FOR_DATA_EXPORT = opt_env('ARCHES_NAMESPACE_FOR_DATA_EXPORT')
if USER_ARCHES_NAMESPACE_FOR_DATA_EXPORT:
    # Make this unique, and don't share it with anybody.
    ARCHES_NAMESPACE_FOR_DATA_EXPORT = USER_ARCHES_NAMESPACE_FOR_DATA_EXPORT

ONTOLOGY_PATH = 'ontology/linked_art'
ONTOLOGY_BASE = 'cidoc_crm_v6.2.4.xml'
ONTOLOGY_BASE_NAME = 'Linked Art'
ONTOLOGY_EXT = ['linkedart.xml', 'linkedart_crm_enhancements.xml']
ONTOLOGY_NAMESPACES = {
        "http://purl.org/dc/terms/": "dcterms",
        "http://purl.org/dc/elements/1.1/": "dc",
        "http://schema.org/": "schema",
        "http://www.w3.org/2004/02/skos/core#": "skos",
        "http://www.w3.org/2000/01/rdf-schema#": "rdfs",
        "http://xmlns.com/foaf/0.1/": "foaf",
        "http://www.w3.org/2001/XMLSchema#": "xsd",
        "https://linked.art/ns/terms/": 'la',
    'http://www.w3.org/1999/02/22-rdf-syntax-ns#': 'rdf',
    'http://www.cidoc-crm.org/cidoc-crm/': '',
    'http://www.ics.forth.gr/isl/CRMgeo/': 'geo',
    'http://www.ics.forth.gr/isl/CRMsci/': 'sci'
}

# options are either "PROD" or "DEV" (installing with Dev mode set gets you extra dependencies)
MODE = get_env_variable('DJANGO_MODE')

DEBUG = ast.literal_eval(get_env_variable('DJANGO_DEBUG'))

COUCHDB_URL = 'http://{}:{}@{}:{}'.format(get_env_variable('COUCHDB_USER'), get_env_variable('COUCHDB_PASS'),
                                          get_env_variable('COUCHDB_HOST'),
                                          get_env_variable('COUCHDB_PORT'))  # defaults to localhost:5984

DATABASES = {
    'default': {
        'ENGINE': 'django.contrib.gis.db.backends.postgis',
        'NAME': get_env_variable('PGDBNAME'),
        'USER': get_env_variable('PGUSERNAME'),
        'PASSWORD': get_env_variable('PGPASSWORD'),
        'HOST': get_env_variable('PGHOST'),
        'PORT': get_env_variable('PGPORT'),
        'POSTGIS_TEMPLATE': 'template_postgis_20',
    }
}

ELASTICSEARCH_HTTP_PORT = get_env_variable('ESPORT')
ELASTICSEARCH_HOSTS = [
    {'host': get_env_variable('ESHOST'), 'port': int(ELASTICSEARCH_HTTP_PORT)}
    # or AWS Elasticsearch Service:
    #{'host': get_env_variable('ESHOST'), 'port': 443, "use_ssl": True}
]

USER_ELASTICSEARCH_PREFIX = opt_env('ELASTICSEARCH_PREFIX')
if USER_ELASTICSEARCH_PREFIX:
    ELASTICSEARCH_PREFIX = USER_ELASTICSEARCH_PREFIX

ALLOWED_HOSTS = get_env_variable('DOMAIN_NAMES').split()

USER_SECRET_KEY = opt_env('DJANGO_SECRET_KEY')
if USER_SECRET_KEY:
    # Make this unique, and don't share it with anybody.
    SECRET_KEY = USER_SECRET_KEY

STATIC_ROOT = '/static_root'

APP_NAME = 'AATA'

APP_TITLE = 'AATA | Arches'
COPYRIGHT_TEXT = ''
COPYRIGHT_YEAR = '2019'


#############################################
# ==============LDAP CONFIG START============
#############################################

# set the following to enable the LDAP authentication backend
# To install:
# sudo apt-get install libsasl2-dev python-dev libldap2-dev libssl-dev
# (ENV) $ pip install django-auth-ldap

ARCHES_USE_LDAP = opt_env("USE_LDAP", False)

if ARCHES_USE_LDAP:
    import ldap
    from django_auth_ldap.config import LDAPSearch

    # Baseline configuration.
    AUTHENTICATION_BACKENDS = ('django_auth_ldap.backend.LDAPBackend',) + AUTHENTICATION_BACKENDS
    AUTH_LDAP_SERVER_URI = get_env_variable("AUTH_LDAP_SERVER_URI")


    # Some ldap options for TLS (https://python-ldap.readthedocs.io/en/latest/reference/ldap.html#ldap-options)
    # AUTH_LDAP_CONNECTION_OPTIONS = {
    #   ldap.OPT_REFERRALS: 0,
    #   ldap.OPT_PROTOCOL_VERSION: 3
    #   ldap.OPT_X_TLS_CACERTFILE: '/absolute/path/to/ldap/cert/file.pem',
    #   ldap.OPT_X_TLS: ldap.OPT_X_TLS_DEMAND,
    #   ldap.OPT_X_TLS_DEMAND: True,
    # }

    # By default, all mapped user fields will be updated each time the user logs in.
    # To disable this, set AUTH_LDAP_ALWAYS_UPDATE_USER to False
    AUTH_LDAP_ALWAYS_UPDATE_USER = True   # Default

    AUTH_LDAP_BIND_DN = opt_env("AUTH_LDAP_BIND_DN")
    AUTH_LDAP_BIND_PASSWORD = opt_env("AUTH_LDAP_BIND_PASSWORD")
    AUTH_LDAP_USER_SEARCH = LDAPSearch(
        get_env_variable("AUTH_LDAP_BASE_DN_SEARCH"),
        ldap.SCOPE_SUBTREE,
        '(uid=%(user)s)',
    )
    # Or:
    #AUTH_LDAP_USER_DN_TEMPLATE = 'uid=%(user)s,ou=users,dc=example,dc=org'

    AUTH_LDAP_USER_ATTR_MAP = {"first_name": "givenName",
                               "last_name": "sn",
                               "email": "mail"}
