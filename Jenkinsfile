pipeline {

    agent {
        docker {
            image 'ghcr.io/cirruslabs/flutter:3.35.5'
            args '-v flutter-web:/deploy'
        }
    }


    stages {


        stage('Version Flutter') {
            steps {
                sh '''
                flutter --version
                '''
            }
        }


        stage('Dependencies') {
            steps {
                sh '''
                flutter pub get
                '''
            }
        }


        stage('Analyze') {
            steps {
                sh '''
                 flutter analyze || true
                '''
            }
        }


        stage('Tests') {
            steps {
                sh '''
                flutter test
                '''
            }
        }


stage('Build Web') {
    steps {
        sh '''
        flutter build web --release
        '''
    }
}


stage('Deploy') {
    steps {
        sh '''
        rm -rf /deploy/*
        cp -r build/web/* /deploy/
        '''
    }
}

    }


    post {

        success {
            archiveArtifacts artifacts: 'build/web/**'
        }

    }

}