FROM ubuntu/bind9

# Copy the named.conf file into the container
COPY /etc/bind/ /etc/bind/
COPY /var/cache/bind/ /var/cache/bind/
COPY /var/log/bind/ /var/log/bind/
COPY /var/run/bind/ /var/run/bind/
COPY /var/lib/bind/ /var/lib/bind/

# Expose the DNS port
EXPOSE 53/udp
EXPOSE 53/tcp
# Set the entrypoint to run the bind9 service
ENTRYPOINT ["/usr/sbin/named", "-g", "-c", "/etc/bind/named.conf"]
