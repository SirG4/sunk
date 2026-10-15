FROM nextcloud:31.0.9-apache
ARG SIG
LABEL event.scenario="02-nextcloud" event.sig="${SIG}"
RUN printf '%s\n' "${SIG}" > /usr/share/.evt-nextcloud-state && chmod 0444 /usr/share/.evt-nextcloud-state