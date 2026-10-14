FROM jellyfin/jellyfin:10.11.11

ARG SIG
LABEL event.scenario="01-jellyfin" event.sig="${SIG}"
RUN printf '%s\n' "${SIG}" > /usr/share/.evt-jellyfin-state \
    && chmod 0444 /usr/share/.evt-jellyfin-state