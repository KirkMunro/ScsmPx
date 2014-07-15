<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet
  version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:dq="urn:dal-query"
  exclude-result-prefixes="dq">
  <xsl:output method="xml" version="1.0" encoding="UTF-8" indent="yes" />
  <xsl:template match="/*">
    <Criteria xmlns="http://Microsoft.EnterpriseManagement.Core.Criteria/">
      <xsl:choose>
        <xsl:when test="count(*) &gt; 1">
          <xsl:element name="{Operator}">
            <xsl:apply-templates select="dq:PredicateGroup" />
            <xsl:apply-templates select="dq:Predicate" />
          </xsl:element>
        </xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates select="dq:PredicateGroup" />
          <xsl:apply-templates select="dq:Predicate" />
        </xsl:otherwise>
      </xsl:choose>
    </Criteria>
  </xsl:template>
  <xsl:template match="dq:PredicateGroup">
    <xsl:apply-templates />
  </xsl:template>
  <xsl:template match="dq:Predicate">
    <xsl:element name="Expression" namespace="http://Microsoft.EnterpriseManagement.Core.Criteria/">
      <xsl:choose>
        <xsl:when test="count(*) &gt; 2">
          <xsl:element name="SimpleExpression" namespace="http://Microsoft.EnterpriseManagement.Core.Criteria/">
            <xsl:element name="ValueExpressionLeft" namespace="http://Microsoft.EnterpriseManagement.Core.Criteria/">
              <xsl:apply-templates select="*[1]" />
            </xsl:element>
            <xsl:apply-templates select="dq:Operator" />
            <xsl:element name="ValueExpressionRight" namespace="http://Microsoft.EnterpriseManagement.Core.Criteria/">
              <xsl:apply-templates select="*[last()]" />
            </xsl:element>
          </xsl:element>
        </xsl:when>
        <xsl:otherwise>
          <xsl:element name="UnaryExpression">
            <xsl:element name="ValueExpressionLeft">
              <xsl:apply-templates select="dq:Property" />
            </xsl:element>
            <xsl:apply-templates select="dq:Operator" />
          </xsl:element>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:element>
  </xsl:template>
  <xsl:template match="dq:Property">
    <xsl:element name="Property" namespace="http://Microsoft.EnterpriseManagement.Core.Criteria/">
      <xsl:text>$Context/Property[Type='{0}']/</xsl:text>
      <xsl:value-of select="." />
      <xsl:text>$</xsl:text>
    </xsl:element>
  </xsl:template>
  <xsl:template match="dq:Operator">
    <xsl:element name="Operator" namespace="http://Microsoft.EnterpriseManagement.Core.Criteria/">
      <xsl:choose>
        <xsl:when test="text()='Equals'">
          <xsl:text>Equal</xsl:text>
        </xsl:when>
        <xsl:when test="text()='NotEquals'">
          <xsl:text>NotEqual</xsl:text>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="." />
        </xsl:otherwise>
      </xsl:choose>
    </xsl:element>
  </xsl:template>
  <xsl:template match="dq:Literal|dq:Decimal">
    <xsl:element name="Value" namespace="http://Microsoft.EnterpriseManagement.Core.Criteria/">
      <xsl:value-of select="." />
    </xsl:element>
  </xsl:template>
</xsl:stylesheet>