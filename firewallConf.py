# RUSec Linux Firewall Configuration Script
# 3/5/2025

# Imports
import os
import argparse

# Get firewall status
def getFirewallStatus():
	os.system("sudo ufw status verbose numbered")

# Enables UFW
def enableFirewall():
	os.system("sudo ufw enable")
	os.system("sudo ufw start")
	getFirewallStatus()

# Default firewall configuration (doesn't change)
def defaultConfig():
	# Enable logging
	os.system("sudo ufw logging medium")
	os.system("sudo ufw logging on")
	
	# Anti-lockout rule
	os.system('sudo ufw allow in ssh comment "Allow SSH"')

	# TODO: DNS?
	os.system('sudo ufw allow in dns comment "Allow DNS"')

	# Block Telnet
	os.system('sudo ufw deny telnet     comment "Deny Telnet in"')
	os.system('sudo ufw deny out telnet comment "Deny Telnet out"')

	# Block common Metasploit ports
	os.system('sudo ufw deny 4444 comment "Deny Metasploit"')
	os.system('sudo ufw deny 9001 comment "Deny Metasploit"')

# MAIN
if __name__ == "__main__":
	# Get input from user
	parser = argparse.ArgumentParser()


	# TODO: Check if UFW is installed


	# TODO: Parse file with of ports


	# Perform default configuration
	defaultConfig()


	# TODO: Perform configuration based on user input

	# Enable UFW
	enableFirewall()