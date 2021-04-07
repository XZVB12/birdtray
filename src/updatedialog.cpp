#include "updatedialog.h"
#include "ui_updatedialog.h"
#include "birdtrayapp.h"
#include <utils.h>
#include <QPushButton>

UpdateDialog::UpdateDialog(QWidget* parent) :
        QDialog(parent),
        ui(new Ui::UpdateDialog) {
    ui->setupUi(this);
    ui->currentVersionLabel->setText(Utils::getBirdtrayVersion());
    
    downloadButton = new QPushButton(tr("Download"), ui->buttonBox);
    downloadButton->setDefault(true);
    downloadButton->setAutoDefault(true);
    connect(downloadButton, &QPushButton::clicked, this, &UpdateDialog::onDownloadButtonClicked);
    ignoreVersionButton = new QPushButton(tr("Ignore this version"), ui->buttonBox);
    connect(ignoreVersionButton, &QPushButton::clicked,
            this, &UpdateDialog::onIgnoreVersionClicked);
    ui->buttonBox->addButton(downloadButton, QDialogButtonBox::ButtonRole::AcceptRole);
    ui->buttonBox->addButton(ignoreVersionButton, QDialogButtonBox::ButtonRole::RejectRole);
    ui->buttonBox->addButton(QDialogButtonBox::StandardButton::Cancel);
}

UpdateDialog::~UpdateDialog() {
    delete ui;
    downloadButton->deleteLater();
    ignoreVersionButton->deleteLater();
}

void UpdateDialog::show(const QString &newVersion, const QString &changelog,
                        qulonglong estimatedSize) {
    ui->newVersionLabel->setText(newVersion);
#if QT_VERSION >= QT_VERSION_CHECK(5, 14, 0)
    ui->changelogLabel->setMarkdown(Utils::formatGithubMarkdown(changelog));
#else
    ui->changelogLabel->setText(Utils::formatGithubMarkdown(changelog));
#endif
    if (estimatedSize == (qulonglong) -1) {
        downloadButton->setText(tr("Download"));
    } else {
        downloadButton->setText(tr("Update and restart"));
    }
    if (estimatedSize == 0 || estimatedSize == (qulonglong) -1) {
        ui->estimatedSizeDescLabel->hide();
        ui->estimatedSizeLabel->hide();
    } else {
        ui->estimatedSizeLabel->setText(tr("ca. %1 Mb").arg(qRound(estimatedSize / 1000000.0)));
        ui->estimatedSizeDescLabel->show();
        ui->estimatedSizeLabel->show();
    }
    QDialog::show();
}

void UpdateDialog::onIgnoreVersionClicked() {
    Settings* settings = BirdtrayApp::get()->getSettings();
    settings->mIgnoreUpdateVersion = ui->newVersionLabel->text();
    settings->save();
}
