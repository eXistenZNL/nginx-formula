# Manage core configuration for Nginx
{% from "nginx/map.jinja" import nginx as nginx_map with context %}

# Remove default files
{%- if salt['pillar.get']('nginx:config:cleanup', True) %}
{% for filename in ('default', 'example_ssl') %}
{{ nginx_map.dirs.config }}/conf.d/{{ filename }}.conf:
  file.absent
{% endfor %}
{%- endif %}

################################################################################

# Ensure the "sites-enabled" are included
{%- if salt['pillar.get']('nginx:config:sites_enabled', True) %}
# We need to create (or ensure they exist) additional folders
{% for dir in ( nginx_map.dirs.sites_enabled, nginx_map.dirs.sites_available ) %}
{{ dir }}:
  file.directory:
    - user: root
    - group: root
    - require:
      - pkg: nginx
{% endfor -%}

{{ nginx_map.dirs.config }}/conf.d/include_sites.conf:
  file.managed:
    - contents: 'include {{ nginx_map.dirs.sites_enabled }}/*;'
    - require:
      - pkg: nginx
{%- endif %}

{%- if salt['pillar.get']('nginx:config:security', True) %}
# Lock down NGINX with a security sauce
{{ nginx_map.dirs.config }}/conf.d/security.conf:
  file.managed:
    - source: salt://nginx/files/security.conf
    - template: jinja
    - require:
      - pkg: nginx
{%- endif %}

################################################################################
# Install placeholder
{%- if salt['pillar.get']('nginx:placeholder:install', True) %}
install_placeholder:
  file.managed:
    - name: /usr/share/nginx/html/index.html
    - source: {{ salt['pillar.get']('nginx:placeholder:template', 'salt://nginx/templates/placeholder.html.jinja') }}
    - template: {{ salt['pillar.get']('nginx:placeholder:template_type', 'jinja') }}
    - mode: 644

# Install placeholder vhost
{{ nginx_map.dirs.config }}/sites-enabled/000-placeholder.conf:
  file.managed:
  - source: {{ salt['pillar.get']('nginx:placeholder:config_template', 'salt://nginx/templates/default.conf.jinja') }}
  - template: {{ salt['pillar.get']('nginx:placeholder:config_template_type', 'jinja') }}
  - watch_in:
    - service: nginx
  - require:
    - pkg: nginx
    - file: install_placeholder
  - webroot: /usr/share/nginx/html
  - php: False
  - index: index.html
  - domain: '_'
  - default_server: True
{%- if salt['pillar.get']('nginx:placeholder:enable_ssl', False) %}
  - ssl:
      cert: {{ salt['pillar.get']('nginx:placeholder:ssl_certificate') }}
      spdy: True
      key: {{ salt['pillar.get']('nginx:placeholder:ssl_key') }}
{%- endif %}

{%- endif %}