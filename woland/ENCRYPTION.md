# Encryption Compliance Documentation for Woland and Behemoth

## Introduction
This document provides an overview of the encryption techniques utilized in Behemoth and confirms compliance with encryption regulations and guidelines. Behemoth employs both AES256 encryption from the Go `crypto/aes` package and elliptic encryption from the `github.com/ecies/go/v2` library to ensure data security.

The application is multi-platform and the encryption part is implement in golang, which provides good portability.


## Encryption Techniques

### AES256 Encryption

- **Algorithm:**
Application uses AES2256 cipher block mode for CBC encryption

- **Usage:** 
AES256 encryption is used to secure data stored on remote servers (SFTP or S3). No encrypted data is stored in the application.

- **Implementation:** 
The encryption is implemented using the Go `crypto/aes` package, which adheres to industry-standard encryption practices.

- **Key Management:**
Keys are generated in the application and shared as protected token. Keys are kept in the local application DB (sqlite).

### Elliptic Encryption

- **Algorithm:** 
secp256k1 is used to secure token in the exchange between users and in control files on the remote storage.

- **Usage:** 
Elliptic encryption is employed for protect AES keys and other data in the sharing to other users. Only users with the 
correct private key would be able to decripted the token and access the AES key

- **Implementation:** 
The elliptic encryption is implemented using the `github.com/ecies/go/v2` library, a reputable and secure Go library for elliptic curve cryptography.

- **Key Management:**
Keys are generated in the application and public key are shared as token or links. Keys are kept in the local application DB (sqlite).


## Compliance
Behemoth complies with all relevant encryption regulations and export control laws. We affirm that encryption is used exclusively for legitimate purposes, such as securing user data and communications, and is not employed for illegal or unauthorized activities.

## Contact Information

For inquiries or additional information related to encryption compliance, please open an issue on https://github.com/stregato/master


## Attestation

We hereby attest that this Encryption Compliance Documentation is accurate and complete to the best of our knowledge.

- **Date:** 30/10/2023


---

This document is for informational purposes and is subject to updates and revisions as necessary to maintain compliance with encryption regulations and industry best practices.
