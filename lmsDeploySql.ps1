function Deploy-SqlLms {
    param($environment='local')
    $servers = @{local = 'localhost'; dev = 'DevSQL\dev2005'; dev01 = 'DevSQL\dev2005'; test = 'TestSQL\Test2005'}
    $databases = @{local = 'LOCAL_IHIDB'; dev = 'DEV_IHIDB'; dev01 = 'DEV01_IHIDB'; test = 'TEST_IHIDB'}
    $sqlPrefix = "& sqlcmd -S $([string]$servers[$environment]) -d $([string]$databases[$environment]) -i "

    function runSql ($sqlFileToRun) {
	    "Running sql script: " + $sqlFileToRun
	    iex $($sqlPrefix + $sqlFileToRun)
    }


    runSql("C:\Ihi2\Database\IHI\CreateScripts\LMS\LMS_CertificateAndSurveyCenterCreateScripts.SQL")
    runSql("C:\Ihi2\Database\IHI\CreateScripts\LMS\LMS_CreationScripts.sql")
    runSql("C:\Ihi2\Database\IHI\ReferenceData\LMS\crtFolderGroups_crtFolders.sql")
    runSql("C:\Ihi2\Database\IHI\ReferenceData\LMS\se_SurveyType.sql")
    runSql("C:\Ihi2\Database\IHI\ReferenceData\LMS\refGroup_refStatus_refStatusGroup.sql")
    runSql("C:\Ihi2\Database\IHI\ReferenceData\LMS\lmsWorkflowType.sql")
    runSql("C:\Ihi2\Database\IHI\ReferenceData\LMS\lmsLessonPageType.sql")
    runSql("C:\Ihi2\Database\IHI\ReferenceData\LMS\lmsContributorRole.sql")
    runSql("C:\Ihi2\Database\IHI\ReferenceData\LMS\lmsContentType.sql")
    runSql("C:\Ihi2\Database\IHI\ReferenceData\LMS\lmsCertificateProgram.sql")
    runSql("C:\Ihi2\Database\IHI\ReferenceData\LMS\folFolders.sql")
    runSql("C:\Ihi2\Database\IHI\ReferenceData\LMS\certCertifiableType.sql")
    runSql("C:\Ihi2\Database\IHI\ChangeScripts\LMS\2009_01_21_SetupLMSRequiredValues.sql")
    runSql("C:\Ihi2\Database\IHI\ChangeScripts\LMS\2009_03_13_LmsRoleCreation.sql")
    runSql("C:\Ihi2\Database\IHI\ChangeScripts\LMS\2009_03_17_GrantLmsRoles.sql")
    runSql("C:\Ihi2\Database\IHI\ChangeScripts\LMS\2009_03_27_SchemaUpdateFor_certSessionCredit_certUserCertficate_certUserCredit.sql")
    runSql("C:\Ihi2\Database\IHI\ChangeScripts\LMS\2009_03_12_SchemaUpdateFor_crtFolders.sql")
    runSql("C:\Ihi2\Database\IHI\ChangeScripts\LMS\2009_03_10_SchemaUpdateFor_se_Surveys.sql")
    runSql("C:\Ihi2\Database\IHI\ChangeScripts\LMS\2009_03_05_SchemaUpdateFor_se_SurveyQuestions_se_QuestionChoices.sql")
    runSql("C:\Ihi2\Database\IHI\StoredProcedures/SurveyCenter/dbo.se_SurveyFoldersGet.prc")
    runSql("C:\Ihi2\Database\IHI\StoredProcedures/SurveyCenter/dbo.se_SurveyFoldersByParentGet.prc")
    runSql("C:\Ihi2\Database\IHI\StoredProcedures/LMS/dbo.TRG_lmsCatalog_Delete.sql")
    runSql("C:\Ihi2\Database\IHI\StoredProcedures/LMS/dbo.TRG_lmsCatalog_Insert.sql")
    runSql("C:\Ihi2\Database\IHI\StoredProcedures/LMS/dbo.TRG_lmsCatalog_Update.sql")
    runSql("C:\Ihi2\Database\IHI\StoredProcedures/LMS/dbo.TRG_lmsCatalogCourseMap_Delete.sql")
    runSql("C:\Ihi2\Database\IHI\StoredProcedures/LMS/dbo.TRG_lmsCatalogCourseMap_Insert.sql")
    runSql("C:\Ihi2\Database\IHI\StoredProcedures/LMS/dbo.TRG_lmsCourse_Update.sql")
    runSql("C:\Ihi2\Database\IHI\StoredProcedures/LMS/dbo.TRG_lmsTopic_Update.sql")
}