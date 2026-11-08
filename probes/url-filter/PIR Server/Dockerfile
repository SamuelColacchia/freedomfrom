##
# A sample PIR Server
#
# See:
# https://github.com/apple/pir-service-example
# https://github.com/apple/container
#
### Building
#
#	From the same directory as the `Dockerfile` execute the following build command, which
#   will build the container and name it `pir-server`:
#	
#		% container build -t pir-server .
#
### Running
#	
#	Once built, the container can be run, and optionally follow the server logs:
#	
#		% container run --remove -d -p 8080:8080 --name pir-server pir-server
#		% container logs --follow pir-server
#		# (control-c to exit log following)
#	
### Stopping
#	
#		% container stop pir-server
#	
###

FROM swift:6.1 AS builder

WORKDIR /pir

# Install and build tools

RUN git clone https://github.com/apple/swift-homomorphic-encryption.git
RUN git clone https://github.com/apple/pir-service-example.git

RUN cd swift-homomorphic-encryption; \
	git checkout 1.0.3; \
	swift package experimental-install -c release --product PIRProcessDatabase

RUN cd pir-service-example; \
	git checkout bbb21535; \
	swift package experimental-install -c release --product PIRService

# Construct Database

RUN mkdir data

COPY data/ data/

RUN cd data; \
	~/.swiftpm/bin/PIRProcessDatabase url-config.json

####

FROM swift:6.1-slim

WORKDIR /pir

COPY service-config.json .
COPY --from=builder /root/.swiftpm/bin/PIRService ./bin/PIRService

COPY --from=builder [ \
	"/pir/data/url-*.bin", \
	"/pir/data/url-*.params.txtpb", \
	"./" ]

# /pir/bin/PIRService --hostname 0.0.0.0 --port 8080 service-config.json
CMD ["--hostname", "0.0.0.0", "--port", "8080", "service-config.json"]
ENTRYPOINT ["/pir/bin/PIRService"]
