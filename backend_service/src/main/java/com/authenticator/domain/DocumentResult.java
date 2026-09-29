package com.authenticator.domain;

import java.util.Map;

public class DocumentResult {
    private String status;
    private String documentNumber;
    private String firstName;
    private String lastName;
    private String dateOfBirth;
    private String expirationDate;
    private String gender;
    private String tramiteNumber;
    private Map<String, Boolean> validations;

    public DocumentResult() {}

    // Getters and setters
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public String getDocumentNumber() { return documentNumber; }
    public void setDocumentNumber(String documentNumber) { this.documentNumber = documentNumber; }

    public String getFirstName() { return firstName; }
    public void setFirstName(String firstName) { this.firstName = firstName; }

    public String getLastName() { return lastName; }
    public void setLastName(String lastName) { this.lastName = lastName; }

    public String getDateOfBirth() { return dateOfBirth; }
    public void setDateOfBirth(String dateOfBirth) { this.dateOfBirth = dateOfBirth; }

    public String getExpirationDate() { return expirationDate; }
    public void setExpirationDate(String expirationDate) { this.expirationDate = expirationDate; }

    public String getGender() { return gender; }
    public void setGender(String gender) { this.gender = gender; }

    public String getTramiteNumber() { return tramiteNumber; }
    public void setTramiteNumber(String tramiteNumber) { this.tramiteNumber = tramiteNumber; }

    public Map<String, Boolean> getValidations() { return validations; }
    public void setValidations(Map<String, Boolean> validations) { this.validations = validations; }
}
