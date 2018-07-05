#change this will upgrade tarball, app's version name, number.
PACKAGENAME=sdk
VERSIONNAME=1.0.6
VERSIONNUMBER=10006
OUTPATH=..
TARBALL=$(PACKAGENAME)-$(VERSIONNAME).git.tar.gz

$(OUTPATH)/$(TARBALL):
	@cd $(OUTPATH) && tar czf $(TARBALL) sdk

.PHONY:all ball
all:ball
ball:
	@rm -rf $(OUTPATH)/$(TARBALL)
	@make $(OUTPATH)/$(TARBALL)

#///////////////////////////////////////////////////////////////////////
# clean
#///////////////////////////////////////////////////////////////////////
clean:
	$(ECHO) "Clean Project.... "
	$(ECHO) "Clean Done"	
